const std = @import("std");

pub const Vertex = extern struct {
    position: [3]f32,
    color: [4]f32,
};

pub const Triangle = struct {
    vertices: [3]Vertex,

    pub fn init() Triangle {
        return Triangle{
            .vertices = [_]Vertex{
                .{ .position = .{ 0.0, -0.6, 0.0 }, .color = .{ 1.0, 0.0, 0.0, 1.0 } },
                .{ .position = .{ -0.6, 0.6, 0.0 }, .color = .{ 0.0, 1.0, 0.0, 1.0 } },
                .{ .position = .{ 0.6, 0.6, 0.0 }, .color = .{ 0.0, 0.0, 1.0, 1.0 } },
            },
        };
    }

    pub fn asBytes(self: *const Triangle) []const u8 {
        return std.mem.asBytes(&self.vertices);
    }

    pub fn vertexCount(self: *const Triangle) u32 {
        _ = self;
        return 3;
    }
};
