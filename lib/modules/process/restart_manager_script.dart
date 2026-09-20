// Restart Manager inspects file handles, not just executable/module paths.
const restartManagerScript = r'''
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class JaRestartManager {
  [StructLayout(LayoutKind.Sequential)]
  public struct UniqueProcess {
    public uint Id;
    public System.Runtime.InteropServices.ComTypes.FILETIME Started;
  }
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct ProcessInfo {
    public UniqueProcess Process;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=256)] public string Name;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=64)] public string Service;
    public int Type;
    public uint Status;
    public uint Session;
    [MarshalAs(UnmanagedType.Bool)] public bool Restartable;
  }
  [DllImport("rstrtmgr.dll", CharSet=CharSet.Unicode)]
  static extern int RmStartSession(out uint handle, uint flags, string key);
  [DllImport("rstrtmgr.dll")]
  static extern int RmEndSession(uint handle);
  [DllImport("rstrtmgr.dll", CharSet=CharSet.Unicode)]
  static extern int RmRegisterResources(uint handle, uint count, string[] files,
    uint apps, UniqueProcess[] processes, uint services, string[] names);
  [DllImport("rstrtmgr.dll", CharSet=CharSet.Unicode)]
  static extern int RmGetList(uint handle, out uint needed, ref uint count,
    [In, Out] ProcessInfo[] info, out uint reasons);
  public static uint[] Find(string[] files) {
    uint handle;
    int error = RmStartSession(out handle, 0, Guid.NewGuid().ToString("N"));
    if (error != 0) throw new Exception("RmStartSession: " + error);
    try {
      error = RmRegisterResources(handle, (uint)files.Length, files, 0, null, 0, null);
      if (error != 0) throw new Exception("RmRegisterResources: " + error);
      uint needed = 0, count = 0, reasons;
      ProcessInfo[] info = null;
      for (int attempt = 0; attempt < 5; attempt++) {
        error = RmGetList(handle, out needed, ref count, info, out reasons);
        if (error == 0) {
          var ids = new List<uint>();
          for (int i=0; i<count; i++) ids.Add(info[i].Process.Id);
          return ids.ToArray();
        }
        if (error != 234) throw new Exception("RmGetList: " + error);
        count = needed;
        info = new ProcessInfo[count];
      }
      throw new Exception("Restart Manager list changed repeatedly");
    } finally { RmEndSession(handle); }
  }
}
'@
$path = [System.IO.Path]::GetFullPath($env:JA_SYMLINK_LOCK_PATH).TrimEnd('\', '/') + '\'
$pattern = [System.Management.Automation.WildcardPattern]::Escape($path) + '*'
$ids = New-Object 'System.Collections.Generic.HashSet[int]'
$pending = New-Object 'System.Collections.Generic.Stack[string]'
$pending.Push($path)
$batch = New-Object 'System.Collections.Generic.List[string]'
while ($pending.Count -gt 0) {
  foreach ($item in Get-ChildItem -LiteralPath $pending.Pop() -Force) {
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
    if ($item.PSIsContainer) { $pending.Push($item.FullName); continue }
    $batch.Add($item.FullName)
    if ($batch.Count -ge 128) {
      foreach ($procId in [JaRestartManager]::Find($batch.ToArray())) { [void]$ids.Add([int]$procId) }
      $batch.Clear()
    }
  }
}
if ($batch.Count -gt 0) {
  foreach ($procId in [JaRestartManager]::Find($batch.ToArray())) { [void]$ids.Add([int]$procId) }
}
$procs = @(Get-Process | Where-Object {
  if ($_.Id -eq $PID) { return $false }
  if ($ids.Contains($_.Id)) { return $true }
  try {
    if ($_.Path -and ($_.Path -like $pattern)) { return $true }
    return ($null -ne ($_.Modules | Where-Object { $_.FileName -like $pattern }))
  } catch { return $false }
} | Select-Object Id, ProcessName, Description, MainWindowTitle, Path)
ConvertTo-Json -InputObject $procs -Compress
''';
