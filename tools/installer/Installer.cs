using System;
using System.Diagnostics;
using System.IO;
using System.IO.Compression;
using System.Reflection;

internal static class Installer
{
    [STAThread]
    private static int Main()
    {
        string self = Assembly.GetExecutingAssembly().Location;
        if (string.IsNullOrEmpty(self))
        {
            Console.Error.WriteLine("Cannot locate installer executable.");
            return 1;
        }

        string baseDir = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "FSYLTV", "setup-temp");
        string tempRoot = Path.Combine(baseDir, Guid.NewGuid().ToString("N"));
        try
        {
            Directory.CreateDirectory(tempRoot);
            byte[] exe = File.ReadAllBytes(self);
            if (exe.Length <= 8)
            {
                Console.Error.WriteLine("Installer payload is missing.");
                return 1;
            }
            long zipLength = BitConverter.ToInt64(exe, exe.Length - 8);
            long zipStart = exe.Length - 8 - zipLength;
            if (zipLength <= 0 || zipStart < 0)
            {
                Console.Error.WriteLine("Installer payload footer is invalid.");
                return 1;
            }

            Directory.CreateDirectory(tempRoot);
            string zipPath = Path.Combine(tempRoot, "payload.zip");
            using (var output = File.Create(zipPath))
            {
                output.Write(exe, (int)zipStart, (int)zipLength);
            }

            string extractDir = Path.Combine(tempRoot, "files");
            Directory.CreateDirectory(extractDir);
            using (var archive = ZipFile.OpenRead(zipPath))
            {
                foreach (var entry in archive.Entries)
                {
                    string target = Path.GetFullPath(
                        Path.Combine(extractDir, entry.FullName));
                    if (!target.StartsWith(extractDir, StringComparison.OrdinalIgnoreCase))
                    {
                        continue;
                    }
                    if (string.IsNullOrEmpty(entry.Name))
                    {
                        Directory.CreateDirectory(target);
                        continue;
                    }
                    Directory.CreateDirectory(Path.GetDirectoryName(target));
                    entry.ExtractToFile(target, true);
                }
            }
            string script = Path.Combine(extractDir, "install.ps1");
            if (!File.Exists(script))
            {
                Console.Error.WriteLine("install.ps1 not found in payload.");
                return 1;
            }

            var info = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = "-NoProfile -ExecutionPolicy Bypass -File \"" + script + "\"",
                WorkingDirectory = extractDir,
                UseShellExecute = false,
                CreateNoWindow = false,
            };
            using (var process = Process.Start(info))
            {
                if (process == null)
                {
                    Console.Error.WriteLine("Failed to start install.ps1.");
                    return 1;
                }
                process.WaitForExit();
                if (process.ExitCode != 0)
                {
                    Console.Error.WriteLine("install.ps1 failed with exit code " + process.ExitCode);
                    return process.ExitCode;
                }
            }
            Console.WriteLine("FSYL TV installed.");
            return 0;
        }
        catch (Exception error)
        {
            Console.Error.WriteLine("Installer failed: " + error.Message);
            return 1;
        }
        finally
        {
            try { if (Directory.Exists(tempRoot)) Directory.Delete(tempRoot, true); }
            catch { }
        }
    }
}
