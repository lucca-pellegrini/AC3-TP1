const std = @import("std");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Read stats file
    const stats_file = std.fs.cwd().openFile("m5out/stats.txt", .{}) catch {
        std.debug.print("Error: Could not open m5out/stats.txt\n", .{});
        std.debug.print("Run gem5 first with: ~/src/gem5/build/ALL/gem5.opt cache_config.py ./zig-out/bin/workload\n", .{});
        return;
    };
    defer stats_file.close();

    const content = try stats_file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);

    // Stats we care about
    var sim_insts: u64 = 0;
    var cpu_cycles: u64 = 0;
    var l1i_hits: u64 = 0;
    var l1i_misses: u64 = 0;
    var l1d_hits: u64 = 0;
    var l1d_misses: u64 = 0;
    var l2_hits: u64 = 0;
    var l2_misses: u64 = 0;
    var l3_hits: u64 = 0;
    var l3_misses: u64 = 0;

    // Parse stats file
    var lines = std.mem.tokenizeScalar(u8, content, '\n');
    while (lines.next()) |line| {
        // Skip comments
        if (line.len == 0 or line[0] == '#') continue;

        // Parse key stats
        if (std.mem.indexOf(u8, line, "simInsts")) |_| {
            if (std.mem.indexOf(u8, line, " ")) |space_idx| {
                const value_str = std.mem.trim(u8, line[space_idx..], " \t");
                if (std.mem.indexOf(u8, value_str, " ")) |end_idx| {
                    sim_insts = std.fmt.parseInt(u64, value_str[0..end_idx], 10) catch 0;
                }
            }
        } else if (std.mem.indexOf(u8, line, "system.cpu.numCycles")) |_| {
            if (std.mem.indexOf(u8, line, " ")) |space_idx| {
                const value_str = std.mem.trim(u8, line[space_idx..], " \t");
                if (std.mem.indexOf(u8, value_str, " ")) |end_idx| {
                    cpu_cycles = std.fmt.parseInt(u64, value_str[0..end_idx], 10) catch 0;
                }
            }
        } else if (std.mem.indexOf(u8, line, "system.cpu.icache.overallHits::total")) |_| {
            if (std.mem.indexOf(u8, line, " ")) |space_idx| {
                const value_str = std.mem.trim(u8, line[space_idx..], " \t");
                if (std.mem.indexOf(u8, value_str, " ")) |end_idx| {
                    l1i_hits = std.fmt.parseInt(u64, value_str[0..end_idx], 10) catch 0;
                }
            }
        } else if (std.mem.indexOf(u8, line, "system.cpu.icache.overallMisses::total")) |_| {
            if (std.mem.indexOf(u8, line, " ")) |space_idx| {
                const value_str = std.mem.trim(u8, line[space_idx..], " \t");
                if (std.mem.indexOf(u8, value_str, " ")) |end_idx| {
                    l1i_misses = std.fmt.parseInt(u64, value_str[0..end_idx], 10) catch 0;
                }
            }
        } else if (std.mem.indexOf(u8, line, "system.cpu.dcache.overallHits::total")) |_| {
            if (std.mem.indexOf(u8, line, " ")) |space_idx| {
                const value_str = std.mem.trim(u8, line[space_idx..], " \t");
                if (std.mem.indexOf(u8, value_str, " ")) |end_idx| {
                    l1d_hits = std.fmt.parseInt(u64, value_str[0..end_idx], 10) catch 0;
                }
            }
        } else if (std.mem.indexOf(u8, line, "system.cpu.dcache.overallMisses::total")) |_| {
            if (std.mem.indexOf(u8, line, " ")) |space_idx| {
                const value_str = std.mem.trim(u8, line[space_idx..], " \t");
                if (std.mem.indexOf(u8, value_str, " ")) |end_idx| {
                    l1d_misses = std.fmt.parseInt(u64, value_str[0..end_idx], 10) catch 0;
                }
            }
        } else if (std.mem.indexOf(u8, line, "system.l2cache.overallHits::total")) |_| {
            if (std.mem.indexOf(u8, line, " ")) |space_idx| {
                const value_str = std.mem.trim(u8, line[space_idx..], " \t");
                if (std.mem.indexOf(u8, value_str, " ")) |end_idx| {
                    l2_hits = std.fmt.parseInt(u64, value_str[0..end_idx], 10) catch 0;
                }
            }
        } else if (std.mem.indexOf(u8, line, "system.l2cache.overallMisses::total")) |_| {
            if (std.mem.indexOf(u8, line, " ")) |space_idx| {
                const value_str = std.mem.trim(u8, line[space_idx..], " \t");
                if (std.mem.indexOf(u8, value_str, " ")) |end_idx| {
                    l2_misses = std.fmt.parseInt(u64, value_str[0..end_idx], 10) catch 0;
                }
            }
        } else if (std.mem.indexOf(u8, line, "system.l3cache.overallHits::total")) |_| {
            if (std.mem.indexOf(u8, line, " ")) |space_idx| {
                const value_str = std.mem.trim(u8, line[space_idx..], " \t");
                if (std.mem.indexOf(u8, value_str, " ")) |end_idx| {
                    l3_hits = std.fmt.parseInt(u64, value_str[0..end_idx], 10) catch 0;
                }
            }
        } else if (std.mem.indexOf(u8, line, "system.l3cache.overallMisses::total")) |_| {
            if (std.mem.indexOf(u8, line, " ")) |space_idx| {
                const value_str = std.mem.trim(u8, line[space_idx..], " \t");
                if (std.mem.indexOf(u8, value_str, " ")) |end_idx| {
                    l3_misses = std.fmt.parseInt(u64, value_str[0..end_idx], 10) catch 0;
                }
            }
        }
    }

    // Calculate metrics
    const l1i_total = l1i_hits + l1i_misses;
    const l1d_total = l1d_hits + l1d_misses;
    const l2_total = l2_hits + l2_misses;
    const l3_total = l3_hits + l3_misses;

    const l1i_miss_rate = if (l1i_total > 0) @as(f64, @floatFromInt(l1i_misses)) / @as(f64, @floatFromInt(l1i_total)) * 100.0 else 0.0;
    const l1d_miss_rate = if (l1d_total > 0) @as(f64, @floatFromInt(l1d_misses)) / @as(f64, @floatFromInt(l1d_total)) * 100.0 else 0.0;
    const l2_miss_rate = if (l2_total > 0) @as(f64, @floatFromInt(l2_misses)) / @as(f64, @floatFromInt(l2_total)) * 100.0 else 0.0;
    const l3_miss_rate = if (l3_total > 0) @as(f64, @floatFromInt(l3_misses)) / @as(f64, @floatFromInt(l3_total)) * 100.0 else 0.0;

    const ipc = if (cpu_cycles > 0) @as(f64, @floatFromInt(sim_insts)) / @as(f64, @floatFromInt(cpu_cycles)) else 0.0;
    const cpi = if (sim_insts > 0) @as(f64, @floatFromInt(cpu_cycles)) / @as(f64, @floatFromInt(sim_insts)) else 0.0;
    const mpki = if (sim_insts > 0) @as(f64, @floatFromInt(l1d_misses + l1i_misses)) * 1000.0 / @as(f64, @floatFromInt(sim_insts)) else 0.0;

    // Print results
    std.debug.print("\n=== CACHE PERFORMANCE ANALYSIS ===\n", .{});
    std.debug.print("\n📊 Basic Metrics:\n", .{});
    std.debug.print("  Instructions: {}\n", .{sim_insts});
    std.debug.print("  CPU Cycles: {}\n", .{cpu_cycles});
    std.debug.print("  IPC: {d:.4}\n", .{ipc});
    std.debug.print("  CPI: {d:.4}\n", .{cpi});

    std.debug.print("\n🎯 Cache Hit/Miss Rates:\n", .{});
    std.debug.print("  L1I: {}/{} (miss rate: {d:.2}%)\n", .{ l1i_hits, l1i_misses, l1i_miss_rate });
    std.debug.print("  L1D: {}/{} (miss rate: {d:.2}%)\n", .{ l1d_hits, l1d_misses, l1d_miss_rate });
    std.debug.print("  L2:  {}/{} (miss rate: {d:.2}%)\n", .{ l2_hits, l2_misses, l2_miss_rate });
    std.debug.print("  L3:  {}/{} (miss rate: {d:.2}%)\n", .{ l3_hits, l3_misses, l3_miss_rate });

    std.debug.print("\n📈 MPKI (Misses Per Kilo Instructions):\n", .{});
    std.debug.print("  Total L1 MPKI: {d:.2}\n", .{mpki});
    if (sim_insts > 0) {
        std.debug.print("  L1I MPKI: {d:.2}\n", .{@as(f64, @floatFromInt(l1i_misses)) * 1000.0 / @as(f64, @floatFromInt(sim_insts))});
        std.debug.print("  L1D MPKI: {d:.2}\n", .{@as(f64, @floatFromInt(l1d_misses)) * 1000.0 / @as(f64, @floatFromInt(sim_insts))});
    }

    std.debug.print("\n", .{});
}
