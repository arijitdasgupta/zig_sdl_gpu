const std = @import("std");

pub const FileWatcher = struct {
    allocator: std.mem.Allocator,
    watched_files: std.ArrayList(WatchedFile),
    
    const WatchedFile = struct {
        path: []const u8,
        last_mtime: i128,
    };

    pub fn init(allocator: std.mem.Allocator) FileWatcher {
        return FileWatcher{
            .allocator = allocator,
            .watched_files = std.ArrayList(WatchedFile){},
        };
    }

    pub fn deinit(self: *FileWatcher) void {
        for (self.watched_files.items) |file| {
            self.allocator.free(file.path);
        }
        self.watched_files.deinit(self.allocator);
    }

    pub fn watch(self: *FileWatcher, path: []const u8) !void {
        const mtime = try getModTime(path);
        const path_copy = try self.allocator.dupe(u8, path);
        try self.watched_files.append(self.allocator, .{
            .path = path_copy,
            .last_mtime = mtime,
        });
    }

    pub fn checkChanges(self: *FileWatcher) !bool {
        var changed = false;
        for (self.watched_files.items) |*file| {
            const current_mtime = getModTime(file.path) catch continue;
            if (current_mtime != file.last_mtime) {
                std.debug.print("File changed: {s}\n", .{file.path});
                file.last_mtime = current_mtime;
                changed = true;
            }
        }
        return changed;
    }
};

fn getModTime(path: []const u8) !i128 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const stat = try file.stat();
    return stat.mtime;
}
