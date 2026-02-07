// raylib-zig (c) Nikolas Wipper 2023

const rl = @import("raylib");
const std = @import("std");

const eql = std.mem.eql;
const ArrayList = std.ArrayList;

const MAX_COLUMNS = 20;

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - 3d camera first person");
    defer rl.closeWindow(); // Close window and OpenGL context

    var camera = rl.Camera3D{
        .position = .init(4, 2, 4),
        .target = .init(0, 1.8, 0),
        .up = .init(0, 1, 0),
        .fovy = 60,
        .projection = .perspective,
    };

    var heights: [MAX_COLUMNS]f32 = undefined;
    var positions: [MAX_COLUMNS]rl.Vector3 = undefined;
    var colors: [MAX_COLUMNS]rl.Color = undefined;

    for (0..heights.len) |i| {
        heights[i] = @as(f32, @floatFromInt(rl.getRandomValue(1, 12)));
        positions[i] = .init(
            @as(f32, @floatFromInt(rl.getRandomValue(-15, 15))),
            heights[i] / 2.0,
            @as(f32, @floatFromInt(rl.getRandomValue(-15, 15))),
        );
        colors[i] = .init(
            @as(u8, @intCast(rl.getRandomValue(20, 255))),
            @as(u8, @intCast(rl.getRandomValue(10, 55))),
            30,
            255,
        );
    }

    const ball = struct {
        position: rl.Vector3,
        velocity: rl.Vector3,
    };

    var player_balls: ArrayList(ball) = .empty;
    defer player_balls.deinit(allocator);

    rl.disableCursor(); // Limit cursor to relative movement inside the window
    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    std.debug.print("Hello, {s}!\n", .{"World"});

    var player_velocity = rl.Vector3.zero();
    const speed = 1.0;
    const gravity = 9.8;

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        camera.update(.first_person);

        // camera.update(.first_person);
        if (rl.isKeyDown(.space)) {
            if (camera.position.y <= 2) {
                player_velocity.y += 5.0;
            }
        }

        camera.position = camera.position.add(player_velocity.scale(rl.getFrameTime() * speed));

        if (camera.position.y < 2) {
            player_velocity = rl.Vector3.zero();
        } else {
            player_velocity.y -= gravity * rl.getFrameTime();
        }

        if (rl.isMouseButtonPressed(.left)) {
            std.debug.print("Button Pressed!\n", .{});
            const forward = camera.target.subtract(camera.position).normalize();
            const bullet_velocity = forward.scale(10.0);
            player_balls.append(allocator, .{
                .position = camera.position,
                .velocity = bullet_velocity,
            }) catch {
                std.debug.print("Failed to append bullet:\n", .{});
            };

            for (player_balls.items) |item| {
                std.debug.print("{d}, ", .{item.position.x});
            }
            std.debug.print("\n", .{});

            // std.debug.print("Button Pressed!\n", .{});
        }

        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.ray_white);

        {
            camera.begin();
            defer camera.end();

            // Draw ground
            rl.drawPlane(.init(0, 0, 0), .init(32, 32), .light_gray);
            rl.drawCube(.init(-16.0, 2.5, 0.0), 1.0, 5.0, 32.0, .blue); // Draw a blue wall
            rl.drawCube(.init(16.0, 2.5, 0.0), 1.0, 5.0, 32.0, .lime); // Draw a green wall
            rl.drawCube(.init(0.0, 2.5, 16.0), 32.0, 5.0, 1.0, .gold); // Draw a yellow wall

            // Draw some cubes around
            for (heights, 0..) |height, i| {
                rl.drawCube(positions[i], 2.0, height, 2.0, colors[i]);
                rl.drawCubeWires(positions[i], 2.0, height, 2.0, .maroon);
            }

            var toRemove: ArrayList(usize) = .empty;
            defer toRemove.deinit(allocator);

            for (player_balls.items, 0..) |bullet, index| {
                rl.drawSphere(bullet.position, 0.2, .red);
                player_balls.items[index].position = bullet.position.add(bullet.velocity.scale(rl.getFrameTime() * speed));
                player_balls.items[index].velocity.y -= gravity * rl.getFrameTime() * 0.5;

                if (bullet.position.y <= 0) {
                    toRemove.append(allocator, index) catch {};
                }
            }

            for (toRemove.items) |index| {
                _ = player_balls.swapRemove(index);
            }
        }

        rl.drawRectangle(10, 10, 220, 70, .fade(.sky_blue, 0.5));
        rl.drawRectangleLines(10, 10, 220, 70, .blue);

        rl.drawText("First person camera default controls:", 20, 20, 10, .black);
        rl.drawText("- Move with keys: W, A, S, D", 40, 40, 10, .dark_gray);
        rl.drawText("- Mouse move to look around", 40, 60, 10, .dark_gray);
        //----------------------------------------------------------------------------------

        rl.drawText(rl.textFormat("- Position: (%06.3f, %06.3f, %06.3f)", .{ camera.position.x, camera.position.y, camera.position.z }), 610, 60, 10, .black);
        rl.drawText(rl.textFormat("- Velocity: (%06.3f, %06.3f, %06.3f)", .{ player_velocity.x, player_velocity.y, player_velocity.z }), 610, 80, 10, .black);
    }
}
