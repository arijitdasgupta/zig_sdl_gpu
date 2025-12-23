pub const Vertex = extern struct {
    position: [3]f32,
    color: [4]f32,
};

pub const triangle_vertices = [_]Vertex{
    .{ .position = .{ 0.0, -0.6, 0.0 }, .color = .{ 1.0, 0.0, 0.0, 1.0 } },
    .{ .position = .{ -0.6, 0.6, 0.0 }, .color = .{ 0.0, 1.0, 0.0, 1.0 } },
    .{ .position = .{ 0.6, 0.6, 0.0 }, .color = .{ 0.0, 0.0, 1.0, 1.0 } },
};
