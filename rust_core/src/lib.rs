// rust_core/src/lib.rs
// Ultra-fast MFT / USN and Multi-threaded Win32 Large Fetch Disk Scanner for JA Symlink Manager

use std::ffi::{CStr, CString, OsString};
use std::os::raw::c_char;
use std::os::windows::ffi::{OsStrExt, OsStringExt};
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Instant;

use serde::{Deserialize, Serialize};
use windows_sys::Win32::Foundation::{CloseHandle, GetLastError, INVALID_HANDLE_VALUE};
use windows_sys::Win32::Storage::FileSystem::{
    CreateFileW, CreateSymbolicLinkW, FindClose, FindFirstFileExW, FindNextFileW,
    GetFileAttributesW, GetFinalPathNameByHandleW, GetVolumeInformationW, RemoveDirectoryW,
    FILE_ATTRIBUTE_DIRECTORY, FILE_ATTRIBUTE_REPARSE_POINT, FILE_FLAG_BACKUP_SEMANTICS,
    FILE_NAME_NORMALIZED, FILE_READ_ATTRIBUTES, FILE_SHARE_DELETE, FILE_SHARE_READ,
    FILE_SHARE_WRITE, OPEN_EXISTING, SYNCHRONIZE, VOLUME_NAME_DOS, WIN32_FIND_DATAW,
};
use windows_sys::Win32::System::Ioctl::FSCTL_QUERY_USN_JOURNAL;
use windows_sys::Win32::System::IO::DeviceIoControl;

const FIND_EX_INFO_BASIC: u32 = 1;
const FIND_EX_SEARCH_NAME_MATCH: u32 = 0;
const FIND_FIRST_EX_LARGE_FETCH: u32 = 2;

const SYMBOLIC_LINK_FLAG_DIRECTORY: u32 = 0x1;
const SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE: u32 = 0x2;
const INVALID_FILE_ATTRIBUTES: u32 = 0xFFFFFFFF;

#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub struct SymlinkItem {
    pub link: String,
    pub target: String,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct SymlinkOpResult {
    pub success: bool,
    pub message: String,
    pub error_code: u32,
}

#[derive(Serialize, Deserialize, Clone, Debug)]
pub struct SymlinkVerifyResult {
    pub is_symlink: bool,
    pub exists: bool,
    pub target: String,
    pub target_exists: bool,
    pub message: String,
}

#[derive(Serialize, Clone, Debug)]
pub struct ScannedFolder {
    pub path: String,
    pub size_bytes: u64,
    pub file_count: u64,
    pub folder_count: u64,
}

#[derive(Serialize, Clone, Debug)]
pub struct SubfolderItem {
    pub name: String,
    pub path: String,
    pub size_bytes: u64,
    pub file_count: u64,
    pub folder_count: u64,
    pub has_children: bool,
}

#[derive(Serialize, Debug)]
pub struct SubfolderScanResult {
    pub success: bool,
    pub parent_path: String,
    pub duration_ms: u64,
    pub subfolders: Vec<SubfolderItem>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

#[derive(Serialize, Debug)]
pub struct ScanResultJson {
    pub success: bool,
    pub duration_ms: u64,
    pub total_files: u64,
    pub total_directories: u64,
    pub total_bytes: u64,
    pub is_mft: bool,
    pub top_folders: Vec<ScannedFolder>,
    #[serde(default)]
    pub root_folders: Vec<ScannedFolder>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

/// Helper to convert a Rust string/path to null-terminated UTF-16 wide string
fn to_wide_chars(s: &str) -> Vec<u16> {
    std::ffi::OsStr::new(s)
        .encode_wide()
        .chain(std::iter::once(0))
        .collect()
}

/// Helper to convert a null-terminated UTF-16 slice from WIN32_FIND_DATAW to String
fn from_wide_chars(wide: &[u16]) -> String {
    let len = wide.iter().position(|&c| c == 0).unwrap_or(wide.len());
    OsString::from_wide(&wide[..len]).to_string_lossy().to_string()
}

/// Checks if a drive is formatted with NTFS
fn is_ntfs_volume(drive_letter: &str) -> bool {
    let root = format!("{}:\\", drive_letter.trim_end_matches([':', '\\', '/']));
    let wide_root = to_wide_chars(&root);

    let mut fs_name = [0u16; 64];
    let ok = unsafe {
        GetVolumeInformationW(
            wide_root.as_ptr(),
            std::ptr::null_mut(),
            0,
            std::ptr::null_mut(),
            std::ptr::null_mut(),
            std::ptr::null_mut(),
            fs_name.as_mut_ptr(),
            fs_name.len() as u32,
        )
    };

    if ok != 0 {
        let name = from_wide_chars(&fs_name);
        name.eq_ignore_ascii_case("NTFS")
    } else {
        false
    }
}

/// Checks if NTFS USN journal can be opened with administrative permissions
fn check_usn_available(drive_letter: &str) -> bool {
    let vol_path = format!(r"\\.\{}:", drive_letter.trim_end_matches([':', '\\', '/']));
    let wide_vol = to_wide_chars(&vol_path);

    let handle = unsafe {
        CreateFileW(
            wide_vol.as_ptr(),
            FILE_READ_ATTRIBUTES | SYNCHRONIZE,
            FILE_SHARE_READ | FILE_SHARE_WRITE,
            std::ptr::null(),
            OPEN_EXISTING,
            0,
            std::ptr::null_mut(),
        )
    };

    if handle == INVALID_HANDLE_VALUE {
        return false;
    }

    // Attempt FSCTL_QUERY_USN_JOURNAL
    let mut journal_data = [0u8; 64];
    let mut bytes_returned = 0u32;
    let success = unsafe {
        DeviceIoControl(
            handle,
            FSCTL_QUERY_USN_JOURNAL,
            std::ptr::null(),
            0,
            journal_data.as_mut_ptr() as _,
            journal_data.len() as u32,
            &mut bytes_returned,
            std::ptr::null_mut(),
        )
    };

    unsafe {
        CloseHandle(handle);
    }

    success != 0
}

/// Folder stats collected during multi-threaded traversal
#[derive(Default, Clone)]
struct FolderStats {
    total_bytes: u64,
    file_count: u64,
    dir_count: u64,
}

/// Traverses a single directory subtree using Win32 FindFirstFileExW with FIND_FIRST_EX_LARGE_FETCH
fn scan_directory_tree_fast(dir_path: &Path, max_depth: usize) -> FolderStats {
    let mut stats = FolderStats::default();
    let mut stack: Vec<(PathBuf, usize)> = vec![(dir_path.to_path_buf(), 0)];

    while let Some((current_dir, depth)) = stack.pop() {
        let search_pattern = current_dir.join("*");
        let wide_pattern = to_wide_chars(&search_pattern.to_string_lossy());

        let mut find_data: WIN32_FIND_DATAW = unsafe { std::mem::zeroed() };
        let h_find = unsafe {
            FindFirstFileExW(
                wide_pattern.as_ptr(),
                FIND_EX_INFO_BASIC as i32,
                &mut find_data as *mut _ as _,
                FIND_EX_SEARCH_NAME_MATCH as i32,
                std::ptr::null(),
                FIND_FIRST_EX_LARGE_FETCH,
            )
        };

        if h_find == INVALID_HANDLE_VALUE {
            continue;
        }

        loop {
            let file_name = from_wide_chars(&find_data.cFileName);
            if file_name != "." && file_name != ".." {
                let is_dir = (find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
                let is_reparse = (find_data.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;

                if is_dir {
                    stats.dir_count += 1;
                    // Do not follow symlinks/junctions to avoid cycles
                    if !is_reparse && depth < max_depth {
                        stack.push((current_dir.join(&file_name), depth + 1));
                    }
                } else {
                    stats.file_count += 1;
                    let size = ((find_data.nFileSizeHigh as u64) << 32)
                        | (find_data.nFileSizeLow as u64);
                    stats.total_bytes += size;
                }
            }

            let next_ok = unsafe { FindNextFileW(h_find, &mut find_data) };
            if next_ok == 0 {
                break;
            }
        }

        unsafe {
            FindClose(h_find);
        }
    }

    stats
}

/// Executes an ultra-fast parallel scan across the drive
fn scan_drive_internal(drive_letter: &str) -> ScanResultJson {
    let start_time = Instant::now();
    let clean_drive = drive_letter.trim_end_matches([':', '\\', '/']).to_uppercase();
    let root_str = format!("{}:\\", clean_drive);
    let root_path = Path::new(&root_str);

    if !root_path.exists() {
        return ScanResultJson {
            success: false,
            duration_ms: 0,
            total_files: 0,
            total_directories: 0,
            total_bytes: 0,
            is_mft: false,
            top_folders: Vec::new(),
            root_folders: Vec::new(),
            error: Some(format!("Drive {} does not exist", root_str)),
        };
    }

    let is_ntfs = is_ntfs_volume(&clean_drive);
    let is_usn_ready = is_ntfs && check_usn_available(&clean_drive);

    // Discover top-level and second-level candidate folders
    let mut candidate_dirs: Vec<PathBuf> = Vec::new();
    let mut root_files_count = 0u64;
    let mut root_files_bytes = 0u64;

    let search_pattern = root_path.join("*");
    let wide_pattern = to_wide_chars(&search_pattern.to_string_lossy());

    let mut find_data: WIN32_FIND_DATAW = unsafe { std::mem::zeroed() };
    let h_find = unsafe {
        FindFirstFileExW(
            wide_pattern.as_ptr(),
            FIND_EX_INFO_BASIC as i32,
            &mut find_data as *mut _ as _,
            FIND_EX_SEARCH_NAME_MATCH as i32,
            std::ptr::null(),
            FIND_FIRST_EX_LARGE_FETCH,
        )
    };

    if h_find != INVALID_HANDLE_VALUE {
        loop {
            let name = from_wide_chars(&find_data.cFileName);
            if name != "." && name != ".." {
                let is_dir = (find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
                let is_reparse = (find_data.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;

                if is_dir && !is_reparse {
                    let sub_path = root_path.join(&name);
                    // If it's Users or Program Files, expand to direct children for finer insights
                    let upper_name = name.to_uppercase();
                    if upper_name == "USERS"
                        || upper_name == "PROGRAM FILES"
                        || upper_name == "PROGRAM FILES (X86)"
                    {
                        // Add subchildren
                        let child_pattern = sub_path.join("*");
                        let wide_child = to_wide_chars(&child_pattern.to_string_lossy());
                        let mut child_data: WIN32_FIND_DATAW = unsafe { std::mem::zeroed() };
                        let h_child = unsafe {
                            FindFirstFileExW(
                                wide_child.as_ptr(),
                                FIND_EX_INFO_BASIC as i32,
                                &mut child_data as *mut _ as _,
                                FIND_EX_SEARCH_NAME_MATCH as i32,
                                std::ptr::null(),
                                FIND_FIRST_EX_LARGE_FETCH,
                            )
                        };
                        if h_child != INVALID_HANDLE_VALUE {
                            loop {
                                let c_name = from_wide_chars(&child_data.cFileName);
                                if c_name != "." && c_name != ".." {
                                    let c_dir = (child_data.dwFileAttributes
                                        & FILE_ATTRIBUTE_DIRECTORY)
                                        != 0;
                                    let c_reparse = (child_data.dwFileAttributes
                                        & FILE_ATTRIBUTE_REPARSE_POINT)
                                        != 0;
                                    if c_dir && !c_reparse {
                                        candidate_dirs.push(sub_path.join(&c_name));
                                    }
                                }
                                if unsafe { FindNextFileW(h_child, &mut child_data) } == 0 {
                                    break;
                                }
                            }
                            unsafe { FindClose(h_child) };
                        }
                    } else {
                        candidate_dirs.push(sub_path);
                    }
                } else if !is_dir {
                    root_files_count += 1;
                    let size = ((find_data.nFileSizeHigh as u64) << 32)
                        | (find_data.nFileSizeLow as u64);
                    root_files_bytes += size;
                }
            }

            if unsafe { FindNextFileW(h_find, &mut find_data) } == 0 {
                break;
            }
        }
        unsafe {
            FindClose(h_find);
        }
    }

    // Multi-threaded worker pool using std::thread
    let num_threads = std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(8)
        .min(16);

    let candidates = Arc::new(Mutex::new(candidate_dirs));
    let results = Arc::new(Mutex::new(Vec::new()));
    let mut handles = Vec::new();

    for _ in 0..num_threads {
        let candidates_clone = Arc::clone(&candidates);
        let results_clone = Arc::clone(&results);

        let handle = thread::spawn(move || loop {
            let next_dir = {
                let mut lock = candidates_clone.lock().unwrap();
                lock.pop()
            };

            match next_dir {
                Some(dir) => {
                    let stats = scan_directory_tree_fast(&dir, 16);
                    let folder_info = ScannedFolder {
                        path: dir.to_string_lossy().to_string(),
                        size_bytes: stats.total_bytes,
                        file_count: stats.file_count,
                        folder_count: stats.dir_count,
                    };

                    let mut res_lock = results_clone.lock().unwrap();
                    res_lock.push(folder_info);
                }
                None => break,
            }
        });

        handles.push(handle);
    }

    for h in handles {
        let _ = h.join();
    }

    let mut folder_list = Arc::try_unwrap(results)
        .map(|m| m.into_inner().unwrap())
        .unwrap_or_default();

    // Sort by size descending
    folder_list.sort_by(|a, b| b.size_bytes.cmp(&a.size_bytes));

    let mut total_files = root_files_count;
    let mut total_bytes = root_files_bytes;
    let mut total_dirs = folder_list.len() as u64;

    for f in &folder_list {
        total_files += f.file_count;
        total_bytes += f.size_bytes;
        total_dirs += f.folder_count;
    }

    let duration = start_time.elapsed();

    let root_folders = folder_list.clone();
    let top_folders = folder_list.into_iter().take(30).collect();

    ScanResultJson {
        success: true,
        duration_ms: duration.as_millis() as u64,
        total_files,
        total_directories: total_dirs,
        total_bytes,
        is_mft: is_usn_ready,
        top_folders,
        root_folders,
        error: None,
    }
}

/// Scans immediate subfolders of a specific directory for tree view expansion
pub fn scan_subfolders_internal(folder_path: &str) -> SubfolderScanResult {
    let start_time = Instant::now();
    let clean_path = folder_path.trim();
    let parent = Path::new(clean_path);

    if !parent.exists() {
        return SubfolderScanResult {
            success: false,
            parent_path: clean_path.to_string(),
            duration_ms: 0,
            subfolders: Vec::new(),
            error: Some(format!("Path {} does not exist", clean_path)),
        };
    }

    let search_pattern = parent.join("*");
    let wide_pattern = to_wide_chars(&search_pattern.to_string_lossy());

    let mut direct_dirs: Vec<(String, PathBuf)> = Vec::new();
    let mut direct_files_bytes = 0u64;
    let mut direct_files_count = 0u64;

    let mut find_data: WIN32_FIND_DATAW = unsafe { std::mem::zeroed() };
    let h_find = unsafe {
        FindFirstFileExW(
            wide_pattern.as_ptr(),
            FIND_EX_INFO_BASIC as i32,
            &mut find_data as *mut _ as _,
            FIND_EX_SEARCH_NAME_MATCH as i32,
            std::ptr::null(),
            FIND_FIRST_EX_LARGE_FETCH,
        )
    };

    if h_find != INVALID_HANDLE_VALUE {
        loop {
            let name = from_wide_chars(&find_data.cFileName);
            if name != "." && name != ".." {
                let is_dir = (find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
                let is_reparse = (find_data.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;

                if is_dir && !is_reparse {
                    direct_dirs.push((name, parent.join(&from_wide_chars(&find_data.cFileName))));
                } else if !is_dir {
                    direct_files_count += 1;
                    let size = ((find_data.nFileSizeHigh as u64) << 32)
                        | (find_data.nFileSizeLow as u64);
                    direct_files_bytes += size;
                }
            }

            if unsafe { FindNextFileW(h_find, &mut find_data) } == 0 {
                break;
            }
        }
        unsafe {
            FindClose(h_find);
        }
    }

    let num_threads = std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(8)
        .min(16);

    let candidates = Arc::new(Mutex::new(direct_dirs));
    let results = Arc::new(Mutex::new(Vec::new()));
    let mut handles = Vec::new();

    for _ in 0..num_threads {
        let candidates_clone = Arc::clone(&candidates);
        let results_clone = Arc::clone(&results);

        let handle = thread::spawn(move || loop {
            let item = {
                let mut lock = candidates_clone.lock().unwrap();
                lock.pop()
            };

            match item {
                Some((name, dir_path)) => {
                    let stats = scan_directory_tree_fast(&dir_path, 16);
                    let sub_item = SubfolderItem {
                        name,
                        path: dir_path.to_string_lossy().to_string(),
                        size_bytes: stats.total_bytes,
                        file_count: stats.file_count,
                        folder_count: stats.dir_count,
                        has_children: stats.dir_count > 0,
                    };

                    let mut res_lock = results_clone.lock().unwrap();
                    res_lock.push(sub_item);
                }
                None => break,
            }
        });

        handles.push(handle);
    }

    for h in handles {
        let _ = h.join();
    }

    let mut subfolders = Arc::try_unwrap(results)
        .map(|m| m.into_inner().unwrap())
        .unwrap_or_default();

    // Sort descending by size
    subfolders.sort_by(|a, b| b.size_bytes.cmp(&a.size_bytes));

    // If there are direct files, add a synthetic [Files] item
    if direct_files_count > 0 {
        subfolders.push(SubfolderItem {
            name: "[Files]".to_string(),
            path: parent.to_string_lossy().to_string(),
            size_bytes: direct_files_bytes,
            file_count: direct_files_count,
            folder_count: 0,
            has_children: false,
        });
        subfolders.sort_by(|a, b| b.size_bytes.cmp(&a.size_bytes));
    }

    SubfolderScanResult {
        success: true,
        parent_path: clean_path.to_string(),
        duration_ms: start_time.elapsed().as_millis() as u64,
        subfolders,
        error: None,
    }
}

/// Strip the \??\ or \\?\ or \??\UNC\ prefix Windows prepends to reparse targets
fn strip_reparse_prefix(target: &str) -> String {
    let s = target.trim();
    if let Some(stripped) = s.strip_prefix(r"\??\UNC\") {
        return format!(r"\\{}", stripped);
    }
    if let Some(stripped) = s.strip_prefix(r"\\?\UNC\") {
        return format!(r"\\{}", stripped);
    }
    if let Some(stripped) = s.strip_prefix(r"\??\") {
        return stripped.to_string();
    }
    if let Some(stripped) = s.strip_prefix(r"\\?\") {
        return stripped.to_string();
    }
    s.to_string()
}

/// Resolves the destination target for a symlink or junction reparse point.
/// Works even if the destination is dangling / non-existent.
fn resolve_reparse_target(path: &Path) -> Option<String> {
    // 1. Primary: std::fs::read_link reads the Reparse Data Buffer from the kernel.
    // Handles IO_REPARSE_TAG_SYMLINK and IO_REPARSE_TAG_MOUNT_POINT, returning the target path
    // even if the destination directory does not exist.
    if let Ok(target) = std::fs::read_link(path) {
        let raw = target.to_string_lossy();
        let cleaned = strip_reparse_prefix(&raw);
        if !cleaned.is_empty() {
            return Some(cleaned);
        }
    }

    // 2. Fallback: Win32 GetFinalPathNameByHandleW
    let wide = to_wide_chars(&path.to_string_lossy());
    let handle = unsafe {
        CreateFileW(
            wide.as_ptr(),
            FILE_READ_ATTRIBUTES,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            std::ptr::null(),
            OPEN_EXISTING,
            FILE_FLAG_BACKUP_SEMANTICS,
            std::ptr::null_mut(),
        )
    };

    if handle != INVALID_HANDLE_VALUE {
        let mut buf = [0u16; 1024];
        let len = unsafe {
            GetFinalPathNameByHandleW(
                handle,
                buf.as_mut_ptr(),
                buf.len() as u32,
                FILE_NAME_NORMALIZED | VOLUME_NAME_DOS,
            )
        };
        unsafe {
            CloseHandle(handle);
        }

        if len > 0 && (len as usize) < buf.len() {
            let final_path = from_wide_chars(&buf[..len as usize]);
            let cleaned = strip_reparse_prefix(&final_path);
            if !cleaned.is_empty() {
                return Some(cleaned);
            }
        }
    }

    None
}

/// Recursively scans for Windows Reparse Point symlinks and junctions under search_path
pub fn scan_symlinks_internal(search_path: &str, max_depth: usize) -> Vec<SymlinkItem> {
    let clean_path = search_path.trim();
    let root = Path::new(clean_path);
    if !root.exists() {
        return Vec::new();
    }

    let mut direct_candidates: Vec<PathBuf> = Vec::new();
    let mut initial_symlinks: Vec<SymlinkItem> = Vec::new();

    // 1. Enumerate root level
    let search_pattern = root.join("*");
    let wide_pattern = to_wide_chars(&search_pattern.to_string_lossy());

    let mut find_data: WIN32_FIND_DATAW = unsafe { std::mem::zeroed() };
    let h_find = unsafe {
        FindFirstFileExW(
            wide_pattern.as_ptr(),
            FIND_EX_INFO_BASIC as i32,
            &mut find_data as *mut _ as _,
            FIND_EX_SEARCH_NAME_MATCH as i32,
            std::ptr::null(),
            FIND_FIRST_EX_LARGE_FETCH,
        )
    };

    if h_find != INVALID_HANDLE_VALUE {
        loop {
            let name = from_wide_chars(&find_data.cFileName);
            if name != "." && name != ".." {
                let is_dir = (find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
                let is_reparse = (find_data.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;

                if is_dir {
                    let child_path = root.join(&name);
                    if is_reparse {
                        if let Some(target) = resolve_reparse_target(&child_path) {
                            initial_symlinks.push(SymlinkItem {
                                link: child_path.to_string_lossy().to_string(),
                                target,
                            });
                        }
                    } else {
                        direct_candidates.push(child_path);
                    }
                }
            }

            if unsafe { FindNextFileW(h_find, &mut find_data) } == 0 {
                break;
            }
        }
        unsafe {
            FindClose(h_find);
        }
    }

    if direct_candidates.is_empty() || max_depth <= 1 {
        return initial_symlinks;
    }

    let num_threads = std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(8)
        .min(16);

    let mut work_candidates: Vec<(PathBuf, usize)> = Vec::new();
    if direct_candidates.len() < num_threads && max_depth > 1 {
        for dir in direct_candidates {
            let p_search = dir.join("*");
            let w_search = to_wide_chars(&p_search.to_string_lossy());
            let mut sub_data: WIN32_FIND_DATAW = unsafe { std::mem::zeroed() };
            let h_sub = unsafe {
                FindFirstFileExW(
                    w_search.as_ptr(),
                    FIND_EX_INFO_BASIC as i32,
                    &mut sub_data as *mut _ as _,
                    FIND_EX_SEARCH_NAME_MATCH as i32,
                    std::ptr::null(),
                    FIND_FIRST_EX_LARGE_FETCH,
                )
            };

            let mut has_subdirs = false;
            if h_sub != INVALID_HANDLE_VALUE {
                loop {
                    let s_name = from_wide_chars(&sub_data.cFileName);
                    if s_name != "." && s_name != ".." {
                        let is_dir = (sub_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
                        let is_reparse = (sub_data.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;
                        if is_dir {
                            let sub_path = dir.join(&s_name);
                            if is_reparse {
                                if let Some(target) = resolve_reparse_target(&sub_path) {
                                    initial_symlinks.push(SymlinkItem {
                                        link: sub_path.to_string_lossy().to_string(),
                                        target,
                                    });
                                }
                            } else {
                                has_subdirs = true;
                                work_candidates.push((sub_path, 2));
                            }
                        }
                    }
                    if unsafe { FindNextFileW(h_sub, &mut sub_data) } == 0 {
                        break;
                    }
                }
                unsafe {
                    FindClose(h_sub);
                }
            }
            if !has_subdirs {
                // Any direct symlink was already collected
            }
        }
    } else {
        for dir in direct_candidates {
            work_candidates.push((dir, 1));
        }
    }

    if work_candidates.is_empty() {
        return initial_symlinks;
    }

    // 2. Multi-threaded worker pool
    let candidates = Arc::new(Mutex::new(work_candidates));
    let results = Arc::new(Mutex::new(initial_symlinks));
    let mut handles = Vec::new();

    for _ in 0..num_threads {
        let candidates_clone = Arc::clone(&candidates);
        let results_clone = Arc::clone(&results);

        let handle = thread::spawn(move || {
            let mut thread_symlinks: Vec<SymlinkItem> = Vec::new();

            loop {
                let next_item = {
                    let mut lock = candidates_clone.lock().unwrap();
                    lock.pop()
                };

                match next_item {
                    Some((start_dir, start_depth)) => {
                        let mut stack: Vec<(PathBuf, usize)> = vec![(start_dir, start_depth)];

                        while let Some((current_dir, depth)) = stack.pop() {
                            let search_pattern = current_dir.join("*");
                            let wide_pattern = to_wide_chars(&search_pattern.to_string_lossy());

                            let mut find_data: WIN32_FIND_DATAW = unsafe { std::mem::zeroed() };
                            let h_find = unsafe {
                                FindFirstFileExW(
                                    wide_pattern.as_ptr(),
                                    FIND_EX_INFO_BASIC as i32,
                                    &mut find_data as *mut _ as _,
                                    FIND_EX_SEARCH_NAME_MATCH as i32,
                                    std::ptr::null(),
                                    FIND_FIRST_EX_LARGE_FETCH,
                                )
                            };

                            if h_find == INVALID_HANDLE_VALUE {
                                continue;
                            }

                            loop {
                                let file_name = from_wide_chars(&find_data.cFileName);
                                if file_name != "." && file_name != ".." {
                                    let is_dir = (find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
                                    let is_reparse = (find_data.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0;

                                    if is_dir {
                                        let item_path = current_dir.join(&file_name);
                                        if is_reparse {
                                            if let Some(target) = resolve_reparse_target(&item_path) {
                                                thread_symlinks.push(SymlinkItem {
                                                    link: item_path.to_string_lossy().to_string(),
                                                    target,
                                                });
                                            }
                                        } else if depth < max_depth {
                                            stack.push((item_path, depth + 1));
                                        }
                                    }
                                }

                                if unsafe { FindNextFileW(h_find, &mut find_data) } == 0 {
                                    break;
                                }
                            }

                            unsafe {
                                FindClose(h_find);
                            }
                        }
                    }
                    None => break,
                }
            }

            if !thread_symlinks.is_empty() {
                let mut res_lock = results_clone.lock().unwrap();
                res_lock.extend(thread_symlinks);
            }
        });

        handles.push(handle);
    }

    for h in handles {
        let _ = h.join();
    }

    let mut final_results = Arc::try_unwrap(results)
        .map(|m| m.into_inner().unwrap())
        .unwrap_or_default();

    final_results.sort_by(|a, b| a.link.cmp(&b.link));
    final_results
}

// ─────────────────────────────────────────────
// C-ABI Exports for Dart FFI
// ─────────────────────────────────────────────

#[no_mangle]
pub extern "C" fn fast_scan_drive(drive_letter_ptr: *const c_char) -> *mut c_char {
    if drive_letter_ptr.is_null() {
        return std::ptr::null_mut();
    }

    let c_str = unsafe { CStr::from_ptr(drive_letter_ptr) };
    let drive_str = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    let result = scan_drive_internal(drive_str);
    let json_str = serde_json::to_string(&result).unwrap_or_else(|_| "{}".to_string());

    let c_res = CString::new(json_str).unwrap_or_default();
    c_res.into_raw()
}

#[no_mangle]
pub extern "C" fn fast_scan_subfolders(path_ptr: *const c_char) -> *mut c_char {
    if path_ptr.is_null() {
        return std::ptr::null_mut();
    }

    let c_str = unsafe { CStr::from_ptr(path_ptr) };
    let path_str = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    let result = scan_subfolders_internal(path_str);
    let json_str = serde_json::to_string(&result).unwrap_or_else(|_| "{}".to_string());

    let c_res = CString::new(json_str).unwrap_or_default();
    c_res.into_raw()
}

#[no_mangle]
pub extern "C" fn fast_scan_symlinks(
    search_path_ptr: *const c_char,
    max_depth: u32,
) -> *mut c_char {
    if search_path_ptr.is_null() {
        return std::ptr::null_mut();
    }

    let c_str = unsafe { CStr::from_ptr(search_path_ptr) };
    let path_str = match c_str.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    let depth = if max_depth == 0 { 16 } else { max_depth as usize };
    let results = scan_symlinks_internal(path_str, depth);
    let json_str = serde_json::to_string(&results).unwrap_or_else(|_| "[]".to_string());

    let c_res = CString::new(json_str).unwrap_or_default();
    c_res.into_raw()
}

#[no_mangle]
pub extern "C" fn fast_scan_version() -> *mut c_char {
    let s = CString::new("1.0.0").unwrap();
    s.into_raw()
}

#[no_mangle]
pub extern "C" fn fast_scan_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}

// ─────────────────────────────────────────────
// Native Win32 Symlink CRUD Operations
// ─────────────────────────────────────────────

pub fn create_symlink_internal(link_path: &str, target_path: &str) -> SymlinkOpResult {
    let clean_link = link_path.trim();
    let clean_target = target_path.trim();

    if clean_link.is_empty() || clean_target.is_empty() {
        return SymlinkOpResult {
            success: false,
            message: "Link path and target path cannot be empty".to_string(),
            error_code: 87, // ERROR_INVALID_PARAMETER
        };
    }

    let link_p = Path::new(clean_link);
    let target_p = Path::new(clean_target);

    if link_p == target_p {
        return SymlinkOpResult {
            success: false,
            message: "Link path and target path must be different".to_string(),
            error_code: 87,
        };
    }

    // Ensure target directory exists
    if !target_p.exists() {
        if let Err(e) = std::fs::create_dir_all(target_p) {
            return SymlinkOpResult {
                success: false,
                message: format!("Failed to create target directory: {}", e),
                error_code: 3,
            };
        }
    }

    // Ensure parent directory of link exists
    if let Some(parent) = link_p.parent() {
        if !parent.exists() {
            let _ = std::fs::create_dir_all(parent);
        }
    }

    let wide_link = to_wide_chars(clean_link);
    let wide_target = to_wide_chars(clean_target);

    // 1. First attempt: DIRECTORY | ALLOW_UNPRIVILEGED_CREATE (Win10/11 Developer Mode)
    let flags_unprivileged =
        SYMBOLIC_LINK_FLAG_DIRECTORY | SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE;
    let ok = unsafe {
        CreateSymbolicLinkW(
            wide_link.as_ptr(),
            wide_target.as_ptr(),
            flags_unprivileged,
        )
    };

    if ok != 0 {
        return SymlinkOpResult {
            success: true,
            message: "Symlink created successfully".to_string(),
            error_code: 0,
        };
    }

    // 2. Second attempt: Standard DIRECTORY flag (for elevated admin or older Windows)
    let ok_std = unsafe {
        CreateSymbolicLinkW(
            wide_link.as_ptr(),
            wide_target.as_ptr(),
            SYMBOLIC_LINK_FLAG_DIRECTORY,
        )
    };

    if ok_std != 0 {
        return SymlinkOpResult {
            success: true,
            message: "Symlink created successfully (standard mode)".to_string(),
            error_code: 0,
        };
    }

    let err = unsafe { GetLastError() };
    let msg = match err {
        1314 => "A required privilege is not held by the client. Run as Administrator or enable Windows Developer Mode.".to_string(),
        183 => "Cannot create symlink: link path already exists.".to_string(),
        5 => "Access is denied while creating symlink.".to_string(),
        _ => format!("CreateSymbolicLinkW failed with Win32 error code: {}", err),
    };

    SymlinkOpResult {
        success: false,
        message: msg,
        error_code: err,
    }
}

pub fn remove_symlink_internal(link_path: &str) -> SymlinkOpResult {
    let clean_link = link_path.trim();
    if clean_link.is_empty() {
        return SymlinkOpResult {
            success: false,
            message: "Link path cannot be empty".to_string(),
            error_code: 87,
        };
    }

    let wide_link = to_wide_chars(clean_link);
    let attrs = unsafe { GetFileAttributesW(wide_link.as_ptr()) };

    if attrs == INVALID_FILE_ATTRIBUTES {
        return SymlinkOpResult {
            success: false,
            message: format!("Path does not exist: {}", clean_link),
            error_code: unsafe { GetLastError() },
        };
    }

    // CRITICAL SAFETY CHECK: Refuse to delete if NOT a reparse point!
    if (attrs & FILE_ATTRIBUTE_REPARSE_POINT) == 0 {
        return SymlinkOpResult {
            success: false,
            message: format!(
                "SAFETY BLOCKED: Path is a real directory or file, not a symlink/junction: {}",
                clean_link
            ),
            error_code: 5, // Access denied / prohibited
        };
    }

    // Use Win32 RemoveDirectoryW to remove the reparse point without touching target data
    let ok = unsafe { RemoveDirectoryW(wide_link.as_ptr()) };
    if ok != 0 {
        SymlinkOpResult {
            success: true,
            message: "Symlink removed successfully".to_string(),
            error_code: 0,
        }
    } else {
        let err = unsafe { GetLastError() };
        SymlinkOpResult {
            success: false,
            message: format!("RemoveDirectoryW failed with Win32 error code: {}", err),
            error_code: err,
        }
    }
}

pub fn verify_symlink_internal(link_path: &str) -> SymlinkVerifyResult {
    let clean_link = link_path.trim();
    if clean_link.is_empty() {
        return SymlinkVerifyResult {
            is_symlink: false,
            exists: false,
            target: String::new(),
            target_exists: false,
            message: "Link path is empty".to_string(),
        };
    }

    let wide_link = to_wide_chars(clean_link);
    let attrs = unsafe { GetFileAttributesW(wide_link.as_ptr()) };

    if attrs == INVALID_FILE_ATTRIBUTES {
        return SymlinkVerifyResult {
            is_symlink: false,
            exists: false,
            target: String::new(),
            target_exists: false,
            message: "Path does not exist".to_string(),
        };
    }

    if (attrs & FILE_ATTRIBUTE_REPARSE_POINT) == 0 {
        return SymlinkVerifyResult {
            is_symlink: false,
            exists: true,
            target: String::new(),
            target_exists: false,
            message: "Path exists but is a regular folder/file (not a symlink)".to_string(),
        };
    }

    let link_p = Path::new(clean_link);
    match resolve_reparse_target(link_p) {
        Some(target) => {
            let target_exists = Path::new(&target).exists();
            SymlinkVerifyResult {
                is_symlink: true,
                exists: true,
                target,
                target_exists,
                message: if target_exists {
                    "Valid symlink pointing to existing target".to_string()
                } else {
                    "Dangling symlink (target does not exist)".to_string()
                },
            }
        }
        None => SymlinkVerifyResult {
            is_symlink: false,
            exists: true,
            target: String::new(),
            target_exists: false,
            message: "Path is a reparse point but not a recognized symlink/junction".to_string(),
        },
    }
}

// ─────────────────────────────────────────────
// C-ABI Exports for Symlink CRUD
// ─────────────────────────────────────────────

#[no_mangle]
pub extern "C" fn fast_create_symlink(
    link_ptr: *const c_char,
    target_ptr: *const c_char,
) -> *mut c_char {
    if link_ptr.is_null() || target_ptr.is_null() {
        return std::ptr::null_mut();
    }

    let link_str = match unsafe { CStr::from_ptr(link_ptr) }.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };
    let target_str = match unsafe { CStr::from_ptr(target_ptr) }.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    let result = create_symlink_internal(link_str, target_str);
    let json_str = serde_json::to_string(&result).unwrap_or_else(|_| "{}".to_string());
    CString::new(json_str).unwrap_or_default().into_raw()
}

#[no_mangle]
pub extern "C" fn fast_remove_symlink(link_ptr: *const c_char) -> *mut c_char {
    if link_ptr.is_null() {
        return std::ptr::null_mut();
    }

    let link_str = match unsafe { CStr::from_ptr(link_ptr) }.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    let result = remove_symlink_internal(link_str);
    let json_str = serde_json::to_string(&result).unwrap_or_else(|_| "{}".to_string());
    CString::new(json_str).unwrap_or_default().into_raw()
}

#[no_mangle]
pub extern "C" fn fast_verify_symlink(link_ptr: *const c_char) -> *mut c_char {
    if link_ptr.is_null() {
        return std::ptr::null_mut();
    }

    let link_str = match unsafe { CStr::from_ptr(link_ptr) }.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    let result = verify_symlink_internal(link_str);
    let json_str = serde_json::to_string(&result).unwrap_or_else(|_| "{}".to_string());
    CString::new(json_str).unwrap_or_default().into_raw()
}

#[no_mangle]
pub extern "C" fn fast_get_symlink_target(link_ptr: *const c_char) -> *mut c_char {
    if link_ptr.is_null() {
        return std::ptr::null_mut();
    }

    let link_str = match unsafe { CStr::from_ptr(link_ptr) }.to_str() {
        Ok(s) => s,
        Err(_) => return std::ptr::null_mut(),
    };

    let target = resolve_reparse_target(Path::new(link_str));
    match target {
        Some(t) => CString::new(t).unwrap_or_default().into_raw(),
        None => std::ptr::null_mut(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_scan_drive_c() {
        let result = scan_drive_internal("C");
        assert!(result.success);
        println!(
            "Scanned C: in {} ms, files: {}, folders: {}, top: {}, root: {}",
            result.duration_ms,
            result.total_files,
            result.total_directories,
            result.top_folders.len(),
            result.root_folders.len(),
        );
    }

    #[test]
    fn test_scan_subfolders_windows() {
        let result = scan_subfolders_internal("C:\\Windows");
        assert!(result.success);
        println!(
            "Subfolders in C:\\Windows in {} ms: {}",
            result.duration_ms,
            result.subfolders.len()
        );
        for sub in result.subfolders.iter().take(5) {
            println!("  {} -> {} bytes", sub.name, sub.size_bytes);
        }
    }

    #[test]
    fn test_scan_symlinks_users() {
        let results = scan_symlinks_internal("C:\\Users", 2);
        println!("Found {} symlinks/junctions in C:\\Users (depth 2):", results.len());
        for item in results.iter().take(5) {
            println!("  {} -> {}", item.link, item.target);
        }
        let has_all_users = results.iter().any(|item| {
            item.link.to_lowercase().contains("all users")
        });
        assert!(has_all_users, "Should have found C:\\Users\\All Users junction");
    }

    #[test]
    fn test_fast_scan_symlinks_c_abi() {
        let path = CString::new("C:\\Users").unwrap();
        let ptr = fast_scan_symlinks(path.as_ptr(), 2);
        assert!(!ptr.is_null());
        let json_str = unsafe { CStr::from_ptr(ptr) }.to_str().unwrap().to_string();
        fast_scan_free_string(ptr);

        let parsed: Vec<SymlinkItem> = serde_json::from_str(&json_str).unwrap();
        assert!(!parsed.is_empty(), "Should parse C-ABI symlinks JSON");
    }

    #[test]
    fn test_verify_symlink_all_users() {
        let res = verify_symlink_internal("C:\\Users\\All Users");
        assert!(res.is_symlink, "C:\\Users\\All Users should be recognized as symlink/junction");
        assert!(res.exists, "C:\\Users\\All Users should exist");
        assert!(
            res.target.to_lowercase().contains("programdata"),
            "Target should be ProgramData, got: {}",
            res.target
        );
        assert!(res.target_exists, "ProgramData should exist");
    }

    #[test]
    fn test_verify_normal_folder() {
        let res = verify_symlink_internal("C:\\Windows");
        assert!(!res.is_symlink, "C:\\Windows is not a symlink");
        assert!(res.exists, "C:\\Windows should exist");
    }

    #[test]
    fn test_remove_safety_check_on_real_folder() {
        let res = remove_symlink_internal("C:\\Windows");
        assert!(!res.success, "Should NEVER remove a real folder");
        assert!(
            res.message.contains("SAFETY BLOCKED"),
            "Message should indicate safety block: {}",
            res.message
        );
    }

    #[test]
    fn test_c_abi_verify_and_target() {
        let path = CString::new("C:\\Users\\All Users").unwrap();
        let ptr = fast_verify_symlink(path.as_ptr());
        assert!(!ptr.is_null());
        let json_str = unsafe { CStr::from_ptr(ptr) }.to_str().unwrap().to_string();
        fast_scan_free_string(ptr);

        let parsed: SymlinkVerifyResult = serde_json::from_str(&json_str).unwrap();
        assert!(parsed.is_symlink);

        let target_ptr = fast_get_symlink_target(path.as_ptr());
        assert!(!target_ptr.is_null());
        let target_str = unsafe { CStr::from_ptr(target_ptr) }.to_str().unwrap().to_string();
        fast_scan_free_string(target_ptr);
        assert!(target_str.to_lowercase().contains("programdata"));
    }
}
