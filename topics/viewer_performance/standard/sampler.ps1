# Windows version of sampler.R: samples the memory and CPU of two process trees (the R server and Chrome)
# about every 150 ms and writes the same CSV columns.
# usage: powershell -NoProfile -ExecutionPolicy Bypass -File sampler.ps1 SERVER_PID CHROME_PID OUT.csv STOP_FILE
# SERVER_PID 0: the server is not started yet; its id is read from OUT.csv.pid once that file is there (the
# server columns are 0 until then).
# r_rss / c_rss are the working sets; r_pss / c_pss are private bytes (Windows has no PSS); r_cpu / c_cpu
# the CPU seconds each tree has used so far. A tree is the process and every process whose parent is in
# it and that started after that parent (Windows reuses process ids).
param([uint32]$ServerPid, [uint32]$ChromePid, [string]$Out, [string]$StopFile)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class PerfTree {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  struct PE32 {
    public uint dwSize; public uint cntUsage; public uint th32ProcessID; public IntPtr th32DefaultHeapID;
    public uint th32ModuleID; public uint cntThreads; public uint th32ParentProcessID; public int pcPriClassBase;
    public uint dwFlags; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string szExeFile;
  }
  [StructLayout(LayoutKind.Sequential)]
  struct PMC {
    public uint cb; public uint PageFaultCount; public UIntPtr PeakWorkingSetSize; public UIntPtr WorkingSetSize;
    public UIntPtr QuotaPeakPagedPoolUsage; public UIntPtr QuotaPagedPoolUsage; public UIntPtr QuotaPeakNonPagedPoolUsage;
    public UIntPtr QuotaNonPagedPoolUsage; public UIntPtr PagefileUsage; public UIntPtr PeakPagefileUsage; public UIntPtr PrivateUsage;
  }
  [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr CreateToolhelp32Snapshot(uint flags, uint pid);
  [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern bool Process32FirstW(IntPtr snap, ref PE32 e);
  [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern bool Process32NextW(IntPtr snap, ref PE32 e);
  [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll")] static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
  [DllImport("kernel32.dll")] static extern bool GetProcessTimes(IntPtr h, out long created, out long exited, out long kernel, out long user);
  [DllImport("psapi.dll")] static extern bool GetProcessMemoryInfo(IntPtr h, out PMC c, uint cb);

  struct Info { public bool ok; public long created; public double cpu; public double ws; public double priv; }
  static Info Query(uint pid) {
    Info r = new Info();
    IntPtr h = OpenProcess(0x1000 | 0x0010, false, pid);   // QUERY_LIMITED_INFORMATION | VM_READ
    if (h == IntPtr.Zero) return r;
    long c, e, k, u;
    if (GetProcessTimes(h, out c, out e, out k, out u)) { r.ok = true; r.created = c; r.cpu = (k + u) / 1e7; }
    PMC m;
    if (GetProcessMemoryInfo(h, out m, (uint)Marshal.SizeOf(typeof(PMC)))) { r.ws = (double)m.WorkingSetSize.ToUInt64(); r.priv = (double)m.PrivateUsage.ToUInt64(); }
    CloseHandle(h);
    return r;
  }
  // { r_rss, r_private, c_rss, c_private, r_cpu, c_cpu }
  public static double[] Sample(uint rRoot, uint cRoot) {
    var kids = new Dictionary<uint, List<uint>>();
    IntPtr snap = CreateToolhelp32Snapshot(0x2, 0);
    PE32 e = new PE32(); e.dwSize = (uint)Marshal.SizeOf(typeof(PE32));
    if (Process32FirstW(snap, ref e)) {
      do {
        if (!kids.ContainsKey(e.th32ParentProcessID)) kids[e.th32ParentProcessID] = new List<uint>();
        kids[e.th32ParentProcessID].Add(e.th32ProcessID);
      } while (Process32NextW(snap, ref e));
    }
    CloseHandle(snap);
    double[] a = Tree(rRoot, kids), b = Tree(cRoot, kids);
    return new double[] { a[0], a[1], b[0], b[1], a[2], b[2] };
  }
  static double[] Tree(uint root, Dictionary<uint, List<uint>> kids) {
    double ws = 0, priv = 0, cpu = 0;
    var queue = new Queue<KeyValuePair<uint, long>>(); var seen = new HashSet<uint>();
    Info ri = Query(root);
    if (!ri.ok) return new double[] { 0, 0, 0 };
    queue.Enqueue(new KeyValuePair<uint, long>(root, ri.created));
    while (queue.Count > 0) {
      var p = queue.Dequeue();
      if (!seen.Add(p.Key)) continue;
      Info i = Query(p.Key);
      if (!i.ok) continue;
      ws += i.ws; priv += i.priv; cpu += i.cpu;
      List<uint> ch;
      if (kids.TryGetValue(p.Key, out ch)) foreach (uint c in ch) {
        Info ci = Query(c);
        if (ci.ok && ci.created >= p.Value) queue.Enqueue(new KeyValuePair<uint, long>(c, ci.created));
      }
    }
    return new double[] { ws, priv, cpu };
  }
}
"@
$w = New-Object System.IO.StreamWriter($Out, $false)
$w.AutoFlush = $true
$w.WriteLine('t_ms,r_rss,r_pss,c_rss,c_pss,r_cpu,c_cpu')
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$PidFile = "$Out.pid"
while (-not (Test-Path -LiteralPath $StopFile)) {
  if ($ServerPid -eq 0 -and (Test-Path -LiteralPath $PidFile)) {
    $line = Get-Content -LiteralPath $PidFile -TotalCount 1
    if ($line -match '^\s*\d+\s*$') { $ServerPid = [uint32]$line.Trim() }
  }
  $t = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $s = [PerfTree]::Sample($ServerPid, $ChromePid)
  $w.WriteLine([string]::Format($inv, '{0},{1:F0},{2:F0},{3:F0},{4:F0},{5:F3},{6:F3}', $t, $s[0], $s[1], $s[2], $s[3], $s[4], $s[5]))
  Start-Sleep -Milliseconds 150
}
$w.Close()
