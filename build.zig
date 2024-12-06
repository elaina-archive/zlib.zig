const std = @import("std");
const mem = std.mem;
const fs = std.fs;

fn collectSources(b: *std.Build, path: std.Build.LazyPath, extensions: []const []const u8) []const []const u8 {
    const p = path.getPath(b);

    var dir = fs.openDirAbsolute(p, .{
        .iterate = true,
    }) catch |e| std.debug.panic("Failed to open {s}: {s}", .{ p, @errorName(e) });
    defer dir.close();

    var list = std.ArrayList([]const u8).init(b.allocator);
    defer list.deinit();

    var iter = dir.iterate();
    while (iter.next() catch |e| std.debug.panic("Failed to iterate {s}: {s}", .{ p, @errorName(e) })) |entry| {
        if (entry.kind != .file) continue;

        const ext = fs.path.extension(entry.name);

        for (extensions) |e| {
            if (mem.eql(u8, ext[1..], e)) {
                list.append(b.allocator.dupe(u8, entry.name) catch @panic("OOM")) catch @panic("OOM");
            }
        }
    }

    return list.toOwnedSlice() catch |e| std.debug.panic("Failed to allocate memory: {s}", .{@errorName(e)});
}

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});
    const linkage = b.option(std.builtin.LinkMode, "linkage", "whether to statically or dynamically link the library") orelse @as(std.builtin.LinkMode, if (target.result.isGnuLibC()) .dynamic else .static);

    const zlib_dep = b.dependency("zlib", .{});

    const zlib = std.Build.Step.Compile.create(b, .{
        .name = "z",
        .root_module = .{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        },
        .kind = .lib,
        .linkage = linkage,
    });

    zlib.addCSourceFiles(.{
        .root = zlib_dep.path("."),
        .files = &.{
            "adler32.c",
            "compress.c",
            "crc32.c",
            "deflate.c",
            "gzclose.c",
            "gzlib.c",
            "gzread.c",
            "gzwrite.c",
            "infback.c",
            "inffast.c",
            "inflate.c",
            "inftrees.c",
            "trees.c",
            "uncompr.c",
            "zutil.c",
        },
        .flags = &.{
            "-DHAVE_UNISTD_H=1",
            "-DHAVE_STDARG_H=1",
        },
    });

    zlib.installHeader(zlib_dep.path("zconf.h"), "zconf.h");
    zlib.installHeader(zlib_dep.path("zlib.h"), "zlib.h");

    b.installArtifact(zlib);
}
