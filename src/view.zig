const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
});
const std = @import("std");

const TGA = @import("image/tga.zig");

const Allocator = std.mem.Allocator;
const panic = std.debug.panic;

const vertex =
    \\#version 330 core
    \\
    \\layout (location = 0) in vec4 vertex;
    \\
    \\out vec2 texcoords;
    \\
    \\void main() {
    \\  gl_Position = vec4(vertex.xy, 0.0, 1.0);
    \\  texcoords = vertex.zw;
    \\}
;

const fragment =
    \\#version 330 core
    \\
    \\in vec2 texcoords;
    \\
    \\out vec4 color;
    \\
    \\uniform sampler2D img;
    \\
    \\void main() {
    \\  color = texture(img, texcoords);
    \\}
;

const Shader = struct {
    program: c_uint,

    const Self = @This();

    pub fn compile(vertex_shader_source: []const u8, fragment_shader_source: []const u8) !Self {
        var success: c_int = undefined;

        const vertex_shader = c.glCreateShader(c.GL_VERTEX_SHADER);
        c.glShaderSource(vertex_shader, 1, @ptrCast(&vertex_shader_source), null);
        c.glCompileShader(vertex_shader);
        defer c.glDeleteShader(vertex_shader);

        c.glGetShaderiv(vertex_shader, c.GL_COMPILE_STATUS, &success);
        if (success == c.GL_FALSE)
            panic("Error compiling vertex shader", .{});

        const fragment_shader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
        c.glShaderSource(fragment_shader, 1, @ptrCast(&fragment_shader_source), null);
        c.glCompileShader(fragment_shader);
        defer c.glDeleteShader(fragment_shader);

        c.glGetShaderiv(fragment_shader, c.GL_LINK_STATUS, &success);
        if (success == c.GL_FALSE)
            panic("Error compiling fragment shader", .{});

        const shader_program = c.glCreateProgram();
        c.glAttachShader(shader_program, vertex_shader);
        c.glAttachShader(shader_program, fragment_shader);
        c.glLinkProgram(shader_program);

        c.glGetProgramiv(shader_program, c.GL_LINK_STATUS, &success);
        if (success == c.GL_FALSE)
            panic("Error compiling shader", .{});

        return .{ .program = shader_program };
    }

    pub fn deinit(self: *Self) void {
        c.glDeleteProgram(self.program);
    }

    pub fn use(self: *Self) void {
        c.glUseProgram(self.program);
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.skip();

    if (args.next()) |path| {
        try view(allocator, path);
        return;
    }

    std.debug.print("Usage: view [file]\n", .{});
}

fn resize(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    _ = window;
    c.glViewport(0, 0, width, height);

    // Adjust image in frame so it doesn't look distorted.
}

fn view(allocator: Allocator, path: []const u8) !void {
    if (c.glfwInit() == c.GL_FALSE)
        return error.InitializationError;
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
    if (comptime @import("builtin").os.tag == .macos)
        c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);

    var img = try TGA.from(allocator, path);
    defer img.deinit();

    var name: []const u8 = undefined;
    var it = std.mem.split(u8, path, "/");
    while (it.next()) |buf| {
        if (it.peek() == null)
            name = buf;
    }

    const window = c.glfwCreateWindow(
        @intCast(img.width),
        @intCast(img.height),
        @ptrCast(name),
        null,
        null
    );
    if (window == null) {
        c.glfwTerminate();
        return error.InitializationError;
    }
    c.glfwMakeContextCurrent(window);
    _ = c.glfwSetFramebufferSizeCallback(window, resize);

    if (c.gladLoadGLLoader(@ptrCast(&c.glfwGetProcAddress)) == c.GL_FALSE)
        return error.InitializationError;

    c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);

    var texture: c_uint = undefined;
    c.glGenTextures(1, &texture);
    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_BORDER);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_BORDER);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR_MIPMAP_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    c.glTexImage2D(
        c.GL_TEXTURE_2D,
        0,
        c.GL_RGB,
        @intCast(img.width),
        @intCast(img.height),
        0,
        c.GL_RGB,
        c.GL_UNSIGNED_BYTE,
        @ptrCast(&img.bytes[0])
    );
    c.glGenerateMipmap(c.GL_TEXTURE_2D);

    c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 4);

    var shader = try Shader.compile(vertex, fragment);
    defer shader.deinit();

    var vao: c_uint = undefined;
    var vbo: c_uint = undefined;
    var ebo: c_uint = undefined;

    c.glGenVertexArrays(1, &vao);
    c.glGenBuffers(1, &vbo);
    c.glGenBuffers(1, &ebo);

    c.glBindVertexArray(vao);

    const vertices = [_]c.GLfloat{
        1, 1, 1, 1,
        1, -1, 1, 0,
        -1, -1, 0, 0,
        -1, 1, 0, 1
    };

    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(
        c.GL_ARRAY_BUFFER,
        @sizeOf(c.GLfloat) * vertices.len,
        @ptrCast(&vertices[0]),
        c.GL_STATIC_DRAW
    );

    c.glVertexAttribPointer(
        0,
        4,
        c.GL_FLOAT,
        c.GL_FALSE,
        @sizeOf(c.GLfloat) * 4,
        null
    );
    c.glEnableVertexAttribArray(0);

    const indices = [_]c.GLuint{
        0, 1, 3,
        1, 2, 3
    };

    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
    c.glBufferData(
        c.GL_ELEMENT_ARRAY_BUFFER,
        @sizeOf(c.GLuint) * indices.len,
        @ptrCast(&indices[0]),
        c.GL_STATIC_DRAW
    );

    while (c.glfwWindowShouldClose(window) == 0) {
        c.glClearColor(0.0, 0.0, 0.0, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        shader.use();
        c.glBindTexture(c.GL_TEXTURE_2D, texture);
        c.glBindVertexArray(vao);
        c.glDrawElements(c.GL_TRIANGLES, indices.len, c.GL_UNSIGNED_INT, null);

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }

    c.glfwTerminate();
}
