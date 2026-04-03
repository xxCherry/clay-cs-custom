using Clay.Builder;
using static Bullseye.Targets;
using static SimpleExec.Command;

string workingDirectory = Path.GetDirectoryName(Utilities.GetFilePath())!;

Target("Interop", () =>
{
	string clayH = Path.Combine(workingDirectory, "src/clay/clay.h");
	string clayCs = Path.Combine(workingDirectory, "../Clay-cs/Interop/ClayInterop.cs");

	var interopArgs = string.Join(' ', [
		string.Join(' ', [
			"--config",
			"generate-file-scoped-namespaces",
			"generate-disable-runtime-marshalling",
			"strip-enum-member-type-name",
			"log-exclusions",
			"log-potential-typedef-remappings",
			"exclude-anonymous-field-helpers",
			"unix-types"
		]),
		"--with-access-specifier ClayInterop=Internal",
		string.Join(' ', [
			"--exclude",
			"Clay__Clay_StringWrapper",
			"Clay__Clay__StringArrayWrapper",
			"Clay__Clay_ArenaWrapper",
			"Clay__Clay_DimensionsWrapper",
			"Clay__Clay_Vector2Wrapper",
			"Clay__Clay_ColorWrapper",
			"Clay__Clay_BoundingBoxWrapper",
			"Clay__Clay_ElementIdWrapper",
			"Clay__Clay_CornerRadiusWrapper",
			"Clay__Clay__ElementConfigTypeWrapper",
			"Clay__Clay_LayoutDirectionWrapper",
			"Clay__Clay_LayoutAlignmentXWrapper",
			"Clay__Clay_LayoutAlignmentYWrapper",
			"Clay__Clay__SizingTypeWrapper",
			"Clay__Clay_ChildAlignmentWrapper",
			"Clay__Clay_SizingMinMaxWrapper",
			"Clay__Clay_SizingAxisWrapper",
			"Clay__Clay_SizingWrapper",
			"Clay__Clay_PaddingWrapper",
			"Clay__Clay_LayoutConfigWrapper",
			"Clay__Clay_RectangleElementConfigWrapper",
			"Clay__Clay_TextElementConfigWrapModeWrapper",
			"Clay__Clay_TextElementConfigWrapper",
			"Clay__Clay_ImageElementConfigWrapper",
			"Clay__Clay_FloatingAttachPointTypeWrapper",
			"Clay__Clay_FloatingAttachPointsWrapper",
			"Clay__Clay_PointerCaptureModeWrapper",
			"Clay__Clay_FloatingElementConfigWrapper",
			"Clay__Clay_CustomElementConfigWrapper",
			"Clay__Clay_ScrollElementConfigWrapper",
			"Clay__Clay_BorderWrapper",
			"Clay__Clay_BorderElementConfigWrapper",
			"Clay__Clay_ElementConfigUnionWrapper",
			"Clay__Clay_ElementConfigWrapper",
			"Clay__Clay_ScrollContainerDataWrapper",
			"Clay__Clay_ElementDataWrapper",
			"Clay__Clay_RenderCommandTypeWrapper",
			"Clay__Clay_RenderCommandWrapper",
			"Clay__Clay_RenderCommandArrayWrapper",
			"Clay__Clay_PointerDataInteractionStateWrapper",
			"Clay__Clay_PointerDataWrapper",
			"Clay__Clay_ErrorTypeWrapper",
			"Clay__Clay_ErrorDataWrapper",
			"Clay__Clay_ErrorHandlerWrapper",
			"Clay__Clay_ClipElementConfigWrapper",
			"Clay__StringArray",
			"Clay__SuppressUnusedLatchDefinitionVariableWarning",
		]),

		"--namespace Clay_cs",
		"--methodClassName ClayInterop",
		"--libraryPath Clay",
		$"--file {clayH}",
		$"--output {clayCs}",
	]);
	Run("ClangSharpPInvokeGenerator", interopArgs, workingDirectory);

	// ClangSharpPInvokeGenerator is adding a trailing '}' that breaks compilation
	var text = File.ReadAllText(clayCs);
	var idx = text.LastIndexOf('}');
	text = text.Substring(0, idx);

	// fix naming
	text = text.Replace("_size_e__Union", "ClaySizingUnion");

	File.WriteAllText(clayCs, text);
});

// -------------------------------------------------------------

string zigDllOut = "./zig-out";
BuildData[] buildData =
[
    new("../Clay-cs/runtimes/win-x64/native", [
        new("./bin",
        [
            new FileData("windows-x86_64-shared-Clay.dll", "Clay.dll"),
            new FileData("windows-x86_64-shared-Clay.pdb", "Clay.pdb"),
        ]),
        new("./lib",
        [
            new FileData("windows-x86_64-static-Clay.lib", "Clay.lib"),
        ]),
    ]),

    new("../Clay-cs/runtimes/linux-x64/native", [
        new("./lib",
        [
            new FileData("liblinux-x86_64-shared-Clay.so", "libClay.so"),
            new FileData("liblinux-x86_64-static-Clay.a", "libClay.a"),
        ]),
    ]),

    new("../Clay-cs/runtimes/osx-x64/native", [
        new("./lib",
        [
            new FileData("libmacos-x86_64-shared-Clay.dylib", "libClay.dylib"),
            new FileData("libmacos-x86_64-static-Clay.a", "libClay.a"),
        ]),
    ]),

    new("../Clay-cs/runtimes/osx-arm64/native", [
        new("./lib",
        [
            new FileData("libmacos-aarch64-shared-Clay.dylib", "libClay.dylib"),
            new FileData("libmacos-aarch64-static-Clay.a", "libClay.a"),
        ]),
    ]),

    new("../Clay-cs/runtimes/android-arm/native", [
        new("./lib",
        [
            new FileData("libandroid-armeabi-v7a-shared-Clay.so", "libClay.so"),
        ]),
    ]),

    new("../Clay-cs/runtimes/android-arm64/native", [
        new("./lib",
        [
            new FileData("libandroid-arm64-v8a-shared-Clay.so", "libClay.so"),
        ]),
    ]),
        new("../Clay-cs/runtimes/android-x86/native", [
        new("./lib",
        [
            new FileData("libandroid-x86-shared-Clay.so", "libClay.so"),
        ]),
    ]),

    new("../Clay-cs/runtimes/android-x64/native", [
        new("./lib",
        [
            new FileData("libandroid-x86_64-shared-Clay.so", "libClay.so"),
        ]),
    ]),
];

string? androidNdk = null;

Target("Dll", async () =>
{
	var fromPath = Path.Combine(workingDirectory, zigDllOut);
	// clean build
	if (Directory.Exists(fromPath))
	{
		Directory.Delete(fromPath, true);
	}

	await RunAsync("zig", $"build -Dandroid-ndk=\"{androidNdk}\"", workingDirectory);

	foreach (var data in buildData)
	{
		var destPath = Path.Combine(workingDirectory, data.MoveTo);

		// clean
		if (Directory.Exists(destPath))
		{
			Directory.Delete(destPath, true);
		}

		Directory.CreateDirectory(destPath);

		foreach (var folder in data.Folders)
		{
			foreach (var file in folder.Files)
			{
				var fromFile = Path.Combine(fromPath, folder.FromRelPath, file.Name);
				var toFile = Path.Combine(destPath, file.Rename);

				File.Copy(fromFile, toFile, true);
			}
		}
	}
});

var bullseyeArgs = new List<string>();

for (var i = 0; i < args.Length; i++)
{
    if (args[i] == "--android-ndk" && i + 1 < args.Length)
    {
        androidNdk = args[++i];
    }
    else
    {
        bullseyeArgs.Add(args[i]);
    }
}

Target("default", DependsOn("Dll", "Interop"));
await RunTargetsAndExitAsync(bullseyeArgs, ex => ex is SimpleExec.ExitCodeException);
