using Nashi.Core;
internal static class ToolSetupChecks
{
    internal static void Run(Action<bool,string> check,string root)
    {
        check(!new ToolSetupStatus(false,false).Ready&&new ToolSetupStatus(false,false).Missing.SequenceEqual(new[]{ToolGroup.Media,ToolGroup.Office}),"Clean profile must offer both tool groups");
        check(new ToolSetupStatus(true,false).Missing.SequenceEqual(new[]{ToolGroup.Office}),"Installed media must survive retrying Office setup");
        check(new ToolSetupStatus(true,true).Ready&&new ToolSetupStatus(true,true).Missing.Length==0,"Existing tools must not be downloaded again");
        var directory=Path.Combine(root,"Setup checks");Directory.CreateDirectory(directory);
        try
        {
            var target=Path.Combine(directory,"tools");var stage=Path.Combine(directory,"stage");Directory.CreateDirectory(target);File.WriteAllText(Path.Combine(target,"partial"),"keep");Directory.CreateDirectory(stage);
            bool Complete(string path)=>ToolInstallation.UsableFile(Path.Combine(path,"ready"));
            try{ToolInstallation.Publish(stage,target,Complete);throw new Exception("Incomplete download published");}catch(InvalidDataException){check(File.ReadAllText(Path.Combine(target,"partial"))=="keep","Incomplete download damaged installed tools");}
            File.WriteAllText(Path.Combine(stage,"ready"),"new");ToolInstallation.Publish(stage,target,Complete);
            check(Complete(target)&&!File.Exists(Path.Combine(target,"partial")),"Retry must repair an incomplete tool directory");
            var second=Path.Combine(directory,"second");Directory.CreateDirectory(second);File.WriteAllText(Path.Combine(second,"ready"),"other");ToolInstallation.Publish(second,target,Complete);
            check(File.ReadAllText(Path.Combine(target,"ready"))=="new","Concurrent completed installation must be retained");
            File.Delete(Path.Combine(target,"ready"));File.WriteAllText(Path.Combine(target,"partial"),"rollback");
            try{ToolInstallation.Publish(second,target,p=>{if(p==second){Directory.Delete(second,true);return true;}return false;});throw new Exception("Vanished stage published");}catch(IOException){check(File.ReadAllText(Path.Combine(target,"partial"))=="rollback","Failed replacement did not restore installed tools");}
            File.WriteAllText(Path.Combine(target,"zero.exe"),"");check(!ToolInstallation.UsableFile(Path.Combine(target,"zero.exe")),"Empty placeholder must not count as installed tool");
            var suffix=OperatingSystem.IsWindows()?".exe":"";
            void Write(string path,string text){File.WriteAllText(path,text);ToolInstallation.MakeExecutable(path);}
            var platform=Path.Combine(directory,"platform tools");Directory.CreateDirectory(platform);
            void Tool(string name)=>Write(Path.Combine(platform,name),"x");
            foreach(var name in new[]{"ffmpeg","ffprobe","yt-dlp"})Tool(name+suffix);Tool(OperatingSystem.IsWindows()?"deno":"deno.exe");
            check(!new Toolchain(platform).Ready,"A tool named for another platform must not count as installed");
            Tool("deno"+suffix);check(new Toolchain(platform).Ready&&new Toolchain(platform).Executable("deno")==Path.Combine(platform,"deno"+suffix),"Tools must use this platform's executable names");
            if(!OperatingSystem.IsWindows())
            {
                File.SetUnixFileMode(Path.Combine(platform,"deno"),UnixFileMode.UserRead|UnixFileMode.UserWrite);check(!new Toolchain(platform).Ready,"A tool without the executable bit must not count as installed");
                var metadata=Path.Combine(directory,"metadata");var exiftool=Path.Combine(metadata,"metadata-13.59","exiftool");Directory.CreateDirectory(Path.GetDirectoryName(exiftool)!);File.WriteAllText(exiftool,"x");
                check(new MetadataService(metadata).Executable is null,"Metadata tools without the executable bit must not count as installed");
                ToolInstallation.MakeExecutable(exiftool);check(new MetadataService(metadata).Executable==exiftool,"Executable metadata tools must count as installed");
            }
            var bundled=Path.Combine(directory,"bundled");var installed=Path.Combine(directory,"installed");Directory.CreateDirectory(installed);
            foreach(var name in new[]{"ffmpeg","ffprobe","yt-dlp","deno"})Write(Path.Combine(installed,name+suffix),"tool");
            check(!new Toolchain(bundled).Ready,"Tools on PATH must stay unused without a search path");
            var found=new Toolchain(bundled,string.Join(Path.PathSeparator,"","relative",'"'+installed+'"'));
            check(found.Ready&&found.Executable("yt-dlp")==Path.Combine(installed,"yt-dlp"+suffix),"Installed tools on the search path must be reused");
            check(found.InstallAsync().IsCompletedSuccessfully&&!Directory.Exists(bundled),"Tools on the search path must not be downloaded again");
            var previous=Environment.CurrentDirectory;Environment.CurrentDirectory=installed;
            try{check(!new Toolchain(bundled,".").Ready,"Relative search path entries must be ignored");}finally{Environment.CurrentDirectory=previous;}
            Directory.CreateDirectory(bundled);Write(Path.Combine(bundled,"ffmpeg"+suffix),"pinned");
            check(found.Executable("ffmpeg")==Path.Combine(bundled,"ffmpeg"+suffix)&&found.Executable("ffprobe")==Path.Combine(installed,"ffprobe"+suffix),"Downloaded tools must take priority over the search path");
            Write(Path.Combine(installed,"deno"+suffix),"");check(!found.Ready,"Empty search path placeholder must not count as installed tool");
        }
        finally{Directory.Delete(directory,true);}
    }
}
