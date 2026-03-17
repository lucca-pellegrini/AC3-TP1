const std = @import("std");

pub fn build(b: *std.Build) void {
    // Target x86_64-linux with glibc (for gem5 compatibility)
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_arch = .x86_64,
            .os_tag = .linux,
            .abi = .gnu,
        },
    });

    const optimize = b.standardOptimizeOption(.{});

    // Build all C workloads in the workloads directory
    const workloads = [_][]const u8{
        "matrix_multiply",
        "array_stride",
        "random_access",
    };

    for (workloads) |workload_name| {
        const exe = b.addExecutable(.{
            .name = workload_name,
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
                .link_libc = true,
            }),
        });

        exe.addCSourceFile(.{
            .file = b.path(b.fmt("workloads/{s}.c", .{workload_name})),
            .flags = &[_][]const u8{
                "-std=c99",
                "-D_GNU_SOURCE",
                "-O2",
            },
        });

        b.installArtifact(exe);
    }

    // Build analyzer
    const analyze = b.addExecutable(.{
        .name = "analyze",
        .root_module = b.createModule(.{
            .root_source_file = b.path("analyze.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(analyze);

    const run_analyze = b.addRunArtifact(analyze);
    const analyze_step = b.step("analyze", "Analyze gem5 cache statistics");
    analyze_step.dependOn(&run_analyze.step);
}
