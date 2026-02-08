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

    rl.initAudioDevice(); // Initialize audio device
    defer rl.closeAudioDevice(); // Close audio device

    const boom_sound: rl.Sound = try rl.loadSound("resources/audio/boom.wav"); // Load WAV audio file
    const fxWav: rl.Sound = try rl.loadSound("resources/audio/sound.wav"); // Load WAV audio file
    defer rl.unloadSound(boom_sound); // Unload sound data
    defer rl.unloadSound(fxWav); // Unload sound data

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

    const Enemy = struct {
        position: rl.Vector3,
        health: u32,
    };

    var enemies: ArrayList(Enemy) = .empty;
    defer enemies.deinit(allocator);

    const initial_enemy_count = 5;

    for (0..initial_enemy_count) |_| {
        const enemy_position: rl.Vector3 = .init(
            @as(f32, @floatFromInt(rl.getRandomValue(-15, 15))),
            1.0,
            @as(f32, @floatFromInt(rl.getRandomValue(-15, 15))),
        );
        enemies.append(allocator, .{
            .position = enemy_position,
            .health = 100,
        }) catch {
            std.debug.print("Failed to append enemy:\n", .{});
        };
    }

    rl.disableCursor(); // Limit cursor to relative movement inside the window
    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    std.debug.print("Hello, {s}!\n", .{"World"});

    var player_velocity = rl.Vector3.zero();
    const speed = 1.0;
    const gravity = 9.8;
    const bullet_radius = 0.2;
    const enemy_radius = 1.0;

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
            rl.playSound(fxWav);
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

            var balls_to_remove = std.AutoHashMap(usize, void).init(allocator);
            defer balls_to_remove.deinit();

            var enemies_to_remove = std.AutoHashMap(usize, void).init(allocator);
            defer enemies_to_remove.deinit();

            for (player_balls.items, 0..) |bullet, index| {
                rl.drawSphere(bullet.position, bullet_radius, .yellow);
                player_balls.items[index].position = bullet.position.add(bullet.velocity.scale(rl.getFrameTime() * speed));
                player_balls.items[index].velocity.y -= gravity * rl.getFrameTime() * 0.5;

                if (bullet.position.y <= 0) {
                    try balls_to_remove.put(index, {});
                }

                for (enemies.items, 0..) |enemy, enemy_index| {
                    if (rl.checkCollisionSpheres(enemy.position, enemy_radius, bullet.position, bullet_radius)) {
                        if (enemies.items[enemy_index].health > 20) {
                            enemies.items[enemy_index].health = enemies.items[enemy_index].health - 20;
                        } else {
                            enemies.items[enemy_index].health = 0;
                            try enemies_to_remove.put(enemy_index, {});
                        }
                        try balls_to_remove.put(index, {});

                        rl.playSound(boom_sound);
                    }
                }
            }

            for (enemies.items, 0..) |enemy, index| {
                rl.drawSphere(enemy.position, enemy_radius, .gray);
                // move enemy towards player
                const direction_to_player = camera.position.subtract(enemy.position).normalize();
                enemies.items[index].position = enemy.position.add(direction_to_player.scale(rl.getFrameTime() * 5));

                if (rl.checkCollisionSpheres(enemy.position, enemy_radius, camera.position, 0.5)) {
                    rl.drawRectangle(0, 0, 1000, 1000, .fade(.red, 0.5));

                    // std.debug.print("Player hit by enemy! Game Over!\n", .{});
                    // rl.clearBackground(.ray_white);
                    // camera.end();
                    // rl.endDrawing();
                    // while (true) {
                    //     camera.begin();
                    //     defer camera.end();
                    //     rl.beginDrawing();
                    //     defer rl.endDrawing();
                    //     rl.clearBackground(.black);
                    //     rl.drawText("Game Over! Press Enter to Quit", 20, 20, 300, .red);

                    //     if (rl.isKeyPressed(.enter)) {
                    //         break :main;
                    //     }
                    // }
                }
            }

            var balls_to_remove_iterator = balls_to_remove.iterator();

            while (balls_to_remove_iterator.next()) |entry| {
                _ = player_balls.swapRemove(entry.key_ptr.*);
            }

            var enemies_to_remove_iterator = enemies_to_remove.iterator();
            while (enemies_to_remove_iterator.next()) |entry| {
                _ = enemies.swapRemove(entry.key_ptr.*);
            }
        }

        rl.drawRectangle(10, 10, 220, 70, .fade(.sky_blue, 0.5));
        rl.drawRectangleLines(10, 10, 220, 70, .blue);

        rl.drawText("Shoot Energy Balls with click", 20, 20, 10, .black);
        rl.drawText("Move with keys: W, A, S, D, and Space", 40, 40, 10, .dark_gray);
        rl.drawText("Mouse move to look around", 40, 60, 10, .dark_gray);
        //----------------------------------------------------------------------------------

        // rl.drawText(rl.textFormat("- Position: (%06.3f, %06.3f, %06.3f)", .{ camera.position.x, camera.position.y, camera.position.z }), 610, 60, 10, .black);
        // rl.drawText(rl.textFormat("- Velocity: (%06.3f, %06.3f, %06.3f)", .{ player_velocity.x, player_velocity.y, player_velocity.z }), 610, 80, 10, .black);
    }
}
