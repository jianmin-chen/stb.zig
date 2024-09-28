const c = @cImport({
    @cInclude("glad/glad.h");
    @cInclude("GLFW/glfw3.h");
    @cInclude("stb_image.h");
});
const std = @import("std");

const TGA = @import("tga.zig");

const Allocator = std.mem.Allocator;
const panic = std.debug.panic;

const image_vertex =
    \\#version 330 core
    \\
    \\layout (location = 0) in vec3 a_pos;
    \\layout (location = 1) in vec2 a_texcoords;
    \\
    \\out vec2 texcoords;
    \\
    \\void main() {
    \\  gl_Position = vec4(a_pos, 1.0);
    \\  texcoords = a_texcoords;
    \\}
;
const image_fragment =
    \\#version 330 core
    \\
    \\out vec4 color;
    \\
    \\in vec2 texcoords;
    \\
    \\uniform sampler2D img;
    \\
    \\void main() {
    \\  color = texture(img, texcoords);
    \\}
;

const Shader = struct {
    program: c_uint,

    pub const Self = @This();

    pub fn compile(vertex_shader_source: []const u8, fragment_shader_source: []const u8) !Self {
        var success: c_int = undefined;
        const info_log: [*c]u8 = undefined;

        const vertex_shader = c.glCreateShader(c.GL_VERTEX_SHADER);
        c.glShaderSource(vertex_shader, 1, @ptrCast(&vertex_shader_source), null);
        c.glCompileShader(vertex_shader);
        defer c.glDeleteShader(vertex_shader);

        c.glGetShaderiv(vertex_shader, c.GL_COMPILE_STATUS, &success);
        if (success == c.GL_FALSE) {
            c.glGetShaderInfoLog(vertex_shader, 512, null, info_log);
            const log: [*:0]const u8 = std.mem.span(info_log);
            panic("Error compiling vertex shader: {s}\n", .{log});
        }

        const fragment_shader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
        c.glShaderSource(fragment_shader, 1, @ptrCast(&fragment_shader_source), null);
        c.glCompileShader(fragment_shader);
        defer c.glDeleteShader(fragment_shader);

        c.glGetShaderiv(fragment_shader, c.GL_COMPILE_STATUS, &success);
        if (success == c.GL_FALSE) {
            c.glGetShaderInfoLog(vertex_shader, 512, null, info_log);
            const log: [*:0]const u8 = std.mem.span(info_log);
            panic("Error compiling fragment shader: {s}\n", .{log});
        }

        const shader_program = c.glCreateProgram();
        c.glAttachShader(shader_program, vertex_shader);
        c.glAttachShader(shader_program, fragment_shader);
        c.glLinkProgram(shader_program);

        c.glGetProgramiv(shader_program, c.GL_LINK_STATUS, &success);
        if (success == c.GL_FALSE) {
            c.glGetProgramInfoLog(shader_program, 512, null, info_log);
            const log: [*:0]const u8 = std.mem.span(info_log);
            panic("Program linking failed. {s}\n", .{log});
        }

        return .{
            .program = shader_program
        };
    }

    pub fn use(self: *Self) void {
        c.glUseProgram(self.program);
    }
};

const _ViewError = error{InitializationError};

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

fn error_callback(err: c_int, description: [*c]const u8) callconv(.C) void {
    _ = err;
    panic("Error {s}.\n", .{description});
}

fn resize(window: ?*c.GLFWwindow, width: c_int, height: c_int) callconv(.C) void {
    _ = window;
    c.glViewport(0, 0, width, height);
}

fn view(allocator: Allocator, path: []const u8) !void {
    _ = c.glfwSetErrorCallback(error_callback);

    if (c.glfwInit() == c.GL_FALSE)
        return _ViewError.InitializationError;
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 3);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
    c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);

    var img = try TGA.from(allocator, path);
    defer img.deinit();

    const window = c.glfwCreateWindow(@intCast(img.width), @intCast(img.height), @ptrCast(path), null, null);
    if (window == null) {
        c.glfwTerminate();
        return _ViewError.InitializationError;
    }
    c.glfwMakeContextCurrent(window);
    _ = c.glfwSetFramebufferSizeCallback(window, resize);

    if (c.gladLoadGLLoader(@ptrCast(&c.glfwGetProcAddress)) == c.GL_FALSE)
        return _ViewError.InitializationError;

    var texture: c_uint = undefined;
    // c.glPixelStorei(c.GL_UNPACK_ALIGNMENT, 1);
    c.glGenTextures(1, &texture);
    c.glBindTexture(c.GL_TEXTURE_2D, texture);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR_MIPMAP_LINEAR);
    c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);
    c.glTexImage2D(c.GL_TEXTURE_2D, 0, c.GL_RGB, @intCast(img.width), @intCast(img.height), 0, c.GL_RGB, c.GL_UNSIGNED_BYTE, @ptrCast(&img.bytes[0]));
    c.glGenerateMipmap(c.GL_TEXTURE_2D);

    var shader = try Shader.compile(image_vertex, image_fragment);

    const vertices = [_]c.GLfloat{
        1.0, 1.0, 0.0, 1.0, 1.0, // bottom right
        1.0, -1.0, 0.0, 1.0, 0.0, // top right
        -1.0, -1.0, 0.0, 0.0, 0.0, // top left
        -1.0, 1.0, 0.0, 0.0, 1.0 // bottom left
    };
    const indices = [_]c.GLint{
        0, 1, 3,
        1, 2, 3
    };

    var vbo: c_uint = 0;
    var vao: c_uint = 0;
    var ebo: c_uint = 0;
    c.glGenVertexArrays(1, &vao);
    c.glGenBuffers(1, &vbo);
    c.glGenBuffers(1, &ebo);

    c.glBindVertexArray(vao);

    c.glBindBuffer(c.GL_ARRAY_BUFFER, vbo);
    c.glBufferData(c.GL_ARRAY_BUFFER, @sizeOf(c.GLfloat) * 20, @ptrCast(&vertices[0]), c.GL_STATIC_DRAW);

    c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);
    c.glBufferData(c.GL_ELEMENT_ARRAY_BUFFER, @sizeOf(c.GLint) * 6, @ptrCast(&indices[0]), c.GL_STATIC_DRAW);

    c.glVertexAttribPointer(0, 3, c.GL_FLOAT, c.GL_FALSE, 5 * @sizeOf(c.GLfloat), null);
    c.glEnableVertexAttribArray(0);

    const offset: *const anyopaque = @ptrFromInt(3 * @sizeOf(c.GLfloat));
    c.glVertexAttribPointer(1, 2, c.GL_FLOAT, c.GL_FALSE, 5 * @sizeOf(c.GLfloat), offset);
    c.glEnableVertexAttribArray(1);

    while (c.glfwWindowShouldClose(window) == 0) {
        c.glClearColor(0.0, 0.0, 0.0, 1.0);
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        shader.use();
        c.glBindTexture(c.GL_TEXTURE_2D, texture);
        c.glBindVertexArray(vao);
        c.glDrawElements(c.GL_TRIANGLES, 6, c.GL_UNSIGNED_INT, null);

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();
    }

    c.glfwTerminate();
}
