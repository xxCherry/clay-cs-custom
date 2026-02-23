const std = @import("std");

const TargetData = struct {
    target: std.Target.Query,
    as_dll: bool,
};

const TARGETS = [_]TargetData{
    // Windows
    .{ .target = .{ .cpu_arch = .x86_64, .os_tag = .windows }, .as_dll = true },
    .{ .target = .{ .cpu_arch = .x86_64, .os_tag = .windows }, .as_dll = false },

    // Linux
    .{ .target = .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu }, .as_dll = true },
    .{ .target = .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu }, .as_dll = false },
};

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    for (TARGETS) |t| {
        const name = std.fmt.allocPrint(b.allocator, "{s}-{s}-{s}-Clay", .{
            @tagName(t.target.cpu_arch.?),
            @tagName(t.target.os_tag.?),
            if (t.as_dll) "dll" else "lib",
        }) catch @panic("OOM");

        const resolved_target = b.resolveTargetQuery(t.target);

        const flags = [_][]const u8{
            "-std=c99",
        };

        const lib = b.addLibrary(.{
            .name = name,
            .linkage = if (t.as_dll) .dynamic else .static,
            .root_module = b.createModule(.{
                .target = resolved_target,
                .optimize = optimize,
                .link_libc = true
            })
        });

        lib.root_module.addIncludePath(b.path("src/clay"));
        lib.root_module.addCSourceFile(.{
            .file = b.path("src/clay.c"),
            .flags = &flags,
        });

        if (t.as_dll and t.target.os_tag == .windows) {
            lib.root_module.addCMacro("CLAY_DLL", "1");
        }

        if (t.as_dll and t.target.os_tag == .linux) {
            const install_linux_so = b.addInstallFileWithDir(
                lib.getEmittedBin(),
                .bin,
                lib.out_filename,
            );
            b.getInstallStep().dependOn(&install_linux_so.step);
        } else {
            b.installArtifact(lib);
        }
    }
}
