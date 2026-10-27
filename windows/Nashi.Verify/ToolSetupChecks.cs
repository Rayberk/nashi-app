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
            var platform=Path.Combine(directory,"platform tools");Directory.CreateDirectory(platform);var suffix=OperatingSystem.IsWindows()?".exe":"";
            foreach(var name in new[]{"ffmpeg","ffprobe","yt-dlp"})File.WriteAllText(Path.Combine(platform,name+suffix),"x");File.WriteAllText(Path.Combine(platform,OperatingSystem.IsWindows()?"deno":"deno.exe"),"x");
            check(!new Toolchain(platform).Ready,"A tool named for another platform must not count as installed");
            File.WriteAllText(Path.Combine(platform,"deno"+suffix),"x");check(new Toolchain(platform).Ready&&new Toolchain(platform).Executable("deno")==Path.Combine(platform,"deno"+suffix),"Tools must use this platform's executable names");
        }
        finally{Directory.Delete(directory,true);}
    }
}
