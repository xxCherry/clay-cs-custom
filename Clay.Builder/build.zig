const std = @import("std");

const TargetData = struct {
    target: std.Target.Query,
    shared: bool,
    platform_label: []const u8,
    android_api: ?u32 = null,
};

fn artifactName(b: *std.Build, t: TargetData) []const u8 {
    const kind = if (t.shared) "shared" else "static";
    return std.fmt.allocPrint(b.allocator, "{s}-{s}-Clay", .{
        t.platform_label,
        kind,
    }) catch @panic("OOM");
}

fn androidTripleForArch(arch: std.Target.Cpu.Arch) []const u8 {
    return switch (arch) {
        .arm => "arm-linux-androideabi",
        .aarch64 => "aarch64-linux-android",
        .x86 => "i686-linux-android",
        .x86_64 => "x86_64-linux-android",
        else => @panic("unsupported android arch"),
    };
}

fn makeAndroidLibCFile(
    b: *std.Build,
    ndk_root: []const u8,
    target: std.Target,
    api: u32,
    label: []const u8,
) std.Build.LazyPath {
    const host_tag = "windows-x86_64";
    const triple = androidTripleForArch(target.cpu.arch);

    const sysroot = std.fmt.allocPrint(
        b.allocator,
        "{s}/toolchains/llvm/prebuilt/{s}/sysroot",
        .{ ndk_root, host_tag },
    ) catch @panic("OOM");

    const crt_dir = std.fmt.allocPrint(
        b.allocator,
        "{s}/usr/lib/{s}/{d}",
        .{ sysroot, triple, api },
    ) catch @panic("OOM");

    const text = std.fmt.allocPrint(
        b.allocator,
        \\include_dir={s}/usr/include
        \\sys_include_dir={s}/usr/include/{s}
        \\crt_dir={s}
        \\msvc_lib_dir=
        \\kernel32_lib_dir=
        \\gcc_dir=
    ,
        .{ sysroot, sysroot, triple, crt_dir },
    ) catch @panic("OOM");

    const write_files = b.addWriteFiles();
    return write_files.add(
        std.fmt.allocPrint(b.allocator, "android-{s}.libc.txt", .{label}) catch @panic("OOM"),
        text,
    );
}

const TARGETS = [_]TargetData{
    // Windows
    .{
        .target = .{
            .cpu_arch = .x86_64,
            .os_tag = .windows,
        },
        .shared = true,
        .platform_label = "windows-x86_64",
    },
    .{
        .target = .{
            .cpu_arch = .x86_64,
            .os_tag = .windows,
        },
        .shared = false,
        .platform_label = "windows-x86_64",
    },
    .{
        .target = .{
            .cpu_arch = .aarch64,
            .os_tag = .windows,
        },
        .shared = true,
        .platform_label = "windows-aarch64",
    },
    .{
        .target = .{
            .cpu_arch = .aarch64,
            .os_tag = .windows,
        },
        .shared = false,
        .platform_label = "windows-aarch64",
    },

    // Linux
    .{
        .target = .{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
            .abi = .gnu,
        },
        .shared = true,
        .platform_label = "linux-x86_64",
    },
    .{
        .target = .{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
            .abi = .gnu,
        },
        .shared = false,
        .platform_label = "linux-x86_64",
    },

    // macOS Intel
    .{
        .target = .{
            .cpu_arch = .x86_64,
            .os_tag = .macos,
            .abi = .none,
            .os_version_min = .{
                .semver = .{ .major = 10, .minor = 13, .patch = 0 },
            },
        },
        .shared = true,
        .platform_label = "macos-x86_64",
    },
    .{
        .target = .{
            .cpu_arch = .x86_64,
            .os_tag = .macos,
            .abi = .none,
            .os_version_min = .{
                .semver = .{ .major = 10, .minor = 13, .patch = 0 },
            },
        },
        .shared = false,
        .platform_label = "macos-x86_64",
    },
    .{
        .target = .{
            .cpu_arch = .aarch64,
            .os_tag = .macos,
            .abi = .none,
            .os_version_min = .{
                .semver = .{ .major = 11, .minor = 0, .patch = 0 },
            },
        },
        .shared = true,
        .platform_label = "macos-aarch64",
    },
    .{
        .target = .{
            .cpu_arch = .aarch64,
            .os_tag = .macos,
            .abi = .none,
            .os_version_min = .{
                .semver = .{ .major = 11, .minor = 0, .patch = 0 },
            },
        },
        .shared = false,
        .platform_label = "macos-aarch64",
    },
    .{
        .target = .{
            .cpu_arch = .arm,
            .os_tag = .linux,
            .abi = .androideabi,
            .android_api_level = 24,
        },
        .shared = true,
        .platform_label = "android-armeabi-v7a",
        .android_api = 24,
    },
    .{
        .target = .{
            .cpu_arch = .aarch64,
            .os_tag = .linux,
            .abi = .android,
            .android_api_level = 24,
        },
        .shared = true,
        .platform_label = "android-arm64-v8a",
        .android_api = 24,
    },
    .{
        .target = .{
            .cpu_arch = .x86,
            .os_tag = .linux,
            .abi = .android,
            .android_api_level = 24,
        },
        .shared = true,
        .platform_label = "android-x86",
        .android_api = 24,
    },
    .{
        .target = .{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
            .abi = .android,
            .android_api_level = 24,
        },
        .shared = true,
        .platform_label = "android-x86_64",
        .android_api = 24,
    },
};

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const android_ndk = b.option(
        []const u8,
        "android-ndk",
        "Path to Android NDK root (required for Android builds)",
    );

    const c_flags = [_][]const u8{
        "-std=c99",
    };

    for (TARGETS) |t| {
        const name = artifactName(b, t);
        const resolved_target = b.resolveTargetQuery(t.target);

        const lib = b.addLibrary(.{
            .name = name,
            .linkage = if (t.shared) .dynamic else .static,
            .root_module = b.createModule(.{
                .target = resolved_target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });

        lib.root_module.addIncludePath(b.path("src/clay"));
        lib.root_module.addCSourceFile(.{
            .file = b.path("src/clay.c"),
            .flags = &c_flags,
        });

        if (t.shared and t.target.os_tag == .windows) {
            lib.root_module.addCMacro("CLAY_DLL", "1");
        }

        if (t.android_api) |api| {
            const ndk = android_ndk orelse {
                std.debug.panic(
                    "Android target '{s}' requires -Dandroid-ndk=\"C:\\\\path\\\\to\\\\ndk\"",
                    .{t.platform_label},
                );
            };

            const libc_file = makeAndroidLibCFile(
                b,
                ndk,
                resolved_target.result,
                api,
                t.platform_label,
            );
            lib.setLibCFile(libc_file);
        }

        b.installArtifact(lib);
    }
}
