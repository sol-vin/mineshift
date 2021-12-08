require "raylib-cr"
require "perlin_noise"

require "./seeds"
require "./chasm"
require "./bridge"
require "./beam"
require "./layer"
require "./window"
require "./rope"

require "./colors"

alias Rl = LibRaylib

# Mineshift - Made by sol-vin
#   Explore an endless chasm with an xbox 360 controller, or the keyboard. 
module Mineshift
  # What monitor mineshift should fullscreen on
  MONITOR = 0

  # What controller should we use to control the scene?
  CONTROLLER_PORT = 0

  XBOX_A = 7
  XBOX_B = 6
  XBOX_RB = 11
  XBOX_LB = 9
  XBOX_DLEFT = 4
  XBOX_DRIGHT = 2


  # How much drag the Y axis should have
  Y_FRICTION = 0.9
  # How much drag the X axis should have
  X_FRICTION = 0.9

  # How much the camera should move in response to button presses or analog sticks moving
  X_MOVEMENT_FACTOR = 10

  # What is the maximum amount off the screen the camera should be allowed to pan.
  MAX_X_SCREEN_RATIO = 0.04

  SPEED_MODIFIER = 2.0

  Y_VELOCITY_DAMPEN = 0.25

  module Math
    # Rotates a point around another point
    def self.rotate_point(x, y, ox, oy, deg) : Rl::Vector2
      angle = deg * (::Math::PI/180)
      rx = ::Math.cos(angle) * (x - ox) - ::Math.sin(angle) * (y - oy) + ox
      ry = ::Math.sin(angle) * (x - ox) + ::Math.cos(angle) * (y - oy) + oy
      Rl::Vector2.new(x: rx, y: ry)
    end
  end

  # The textures used by each layer
  class_getter textures = StaticArray(Rl::Texture2D, Layer::MAX).new { Rl::Texture2D.new }

  # The 2D camera
  class_getter camera = Rl::Camera2D.new

  # The screen width
  class_property screen_width : Int32 = 1280
  # The screen height
  class_property screen_height : Int32 = 1024
  # How many `screen_height`s high we should make the final texture. If set to `1.0` it will only reapeat one screen's worth of content.
  class_property height_multiplier = 8
  # Should we show the seed number and color in a tasteful little white box?
  class_property? show_seed = false
  # Should we show the help in a white box?
  class_property? show_help = false

  # Our RNGesus
  class_getter perlin = PerlinNoise.new(1_000_000)

  # What color pallette we are using
  @@color_palette : Array(Rl::Color) = [] of Rl::Color
  # Used for name lookup
  @@color_palette_key : Symbol = :none

  # How much the y axis should be scrolled by. Changed by moving the analog stick or pressing up or down.
  @@y_axis_movement = 0.0_f32
  @@y_velocity = 0.0_f32

  @@x_axis_position = 0.0_f32

  # Run this to clean up old stuff and start again.
  def self.setup(seed = 1_000_000)
    # destroy any old textures.
    destroy

    # zero out old stuff
    @@textures = StaticArray(Rl::Texture2D, Layer::MAX).new { Rl::Texture2D.new }
    @@camera = Rl::Camera2D.new
    @@camera.zoom = 1.0_f32
    @@y_axis_movement = 0.0_f32

    @@perlin = PerlinNoise.new(seed)

    # Choose a color palette
    @@color_palette_key = @@perlin.item(0, colors.keys, Seeds::COLOR)
    @@color_palette = colors[@@color_palette_key]

    render_layers
  end

  def self.destroy
    @@textures.each { |t| Rl.unload_texture t }
  end

  # Render all the layer's textures
  def self.render_layers
    Layer::MAX.to_u8.times do |x| 
      draw_loading(0.2_f32 * (x+1), "Drawing Layer #{x}")
      render_layer x 
    end
  end

  # Render a particular layer's texture
  def self.render_layer(layer : UInt8)
    raise "Invalid layer #{layer}" unless layer < Layer::MAX

    # We will render to this texture for the layer
    render_texture = Rl.load_render_texture(screen_width, Layer.height(layer))

    Rl.begin_texture_mode(render_texture)
    Rl.clear_background(Rl::WHITE)
    Rl.begin_mode_2d(@@camera)

    # Make chasm
    chasm_rects = Chasm.make(layer)
    Chasm.draw(chasm_rects)

    # Make bridges
    bridge_rects = [] of Rl::Rectangle
    if layer < Bridge::LAYER
      bridge_rects = Bridge.make(layer, chasm_rects)
    end

    # Make beams
    beam_rects = [] of Rl::Rectangle
    if layer > Beam::LAYER
      beam_rects = Beam.make(layer, chasm_rects)
    end

    # Make windows
    window_rects = Window.make(layer, chasm_rects)

    # Make rope
    Rope.make(layer, chasm_rects, beam_rects) if layer > 1

    Rl.end_mode_2d
    Rl.end_texture_mode

    # Make an image out of our render texture
    image = Rl.load_image_from_texture(render_texture.texture)

    # Replace the color black with transparency
    Rl.image_color_replace(pointerof(image), Rl::BLACK, Rl::Color.new(r: 0_u8, g: 0_u8, b: 0_u8, a: 0_u8))
    # Reload the texture from the image
    @@textures[layer] = Rl.load_texture_from_image(image)

    # Clean up the old data
    Rl.unload_image(image)
    Rl.unload_render_texture(render_texture)
  end

  # Swaps the color palettes. Used for incrementing and decrementing the current color scheme.
  private def self._swap_palettes(pallete_offset)
    old_palette = @@color_palette
    
    index = 0
    # Does the index exist?
    if index = colors.keys.index(@@color_palette_key)
      index += pallete_offset
      index %= colors.keys.size # rollover positive overflow
      index = colors.keys.size if index < 0 # rollunder negative overflow
      # change the key
      @@color_palette_key = colors.keys[index]
    end
    # change the palette
    @@color_palette = colors[@@color_palette_key]
  end

  # Draw the scene
  def self.draw
    Rl.begin_drawing
    Rl.clear_background(@@color_palette[0])
    Rl.begin_mode_2d(@@camera)

    # Draw each layer
    Layer::MAX.times do |layer|
      # TODO: Clean this up
      layer_offset = 10.0 + (5.0 * ((layer + 1) ** layer) * (@@y_axis_movement * 0.05))
      # Move a layer less the farthe back it is.
      x = @@x_axis_position * (layer+1)
      y = -layer_offset

      # Draw the texture so when scrolling it will move the y of the source rect, causing the texture to repeat.
      Rl.draw_texture_pro(
        @@textures[layer],
        Rl::Rectangle.new(x: x, y: y, width: screen_width, height: -screen_height),
        Rl::Rectangle.new(x: 0, y: 0, width: screen_width, height: screen_height),
        Rl::Vector2.new,
        0.0_f32,
        @@color_palette[layer+1]
      )
    end

    # Show the seed if the variable is true
    if show_seed?
      draw_seed
    end

    if show_help?
      draw_help
    end

    Rl.end_mode_2d
    Rl.end_drawing
  end

  # Draws the help screen
  def self.draw_help
    text_size = 20
    y_spacing = 5
    title = "#{"   " * 10}HELP#{"   " * 10}"
    text_length = Rl.measure_text(title, text_size)

    x = (screen_width / 2.0) - (text_length/2.0)
    y = (screen_height * 0.3)
    w = text_length + (text_size)
    h = (text_size + y_spacing) * 16

    Rl.draw_rectangle(x - (text_size/2.0), y - (text_size/2.0), w, h, Rl::WHITE)
    Rl.draw_rectangle_lines(x - (text_size/2.0), y - (text_size/2.0), w, h, Rl::BLACK)
    Rl.draw_text(title, x, y, text_size, Rl::BLACK)

    Rl.draw_text("A : Next Seed", x, y + (text_size + y_spacing), text_size, Rl::BLACK)
    Rl.draw_text("D : Prev Seed", x, y + (text_size + y_spacing) * 2, text_size, Rl::BLACK)
    Rl.draw_text("Space : Random Seed", x, y + (text_size + y_spacing) * 3, text_size, Rl::BLACK)

    Rl.draw_text("Mouse Wheel Up : Scroll Up", x, y + (text_size + y_spacing) * 6, text_size, Rl::BLACK)
    Rl.draw_text("Mouse Wheel Down : Scroll Down", x, y + (text_size + y_spacing) * 7, text_size, Rl::BLACK)
    Rl.draw_text("Left Right : Pan", x, y + (text_size + y_spacing) * 8, text_size, Rl::BLACK)
    Rl.draw_text("O P : Cycle Colors", x, y + (text_size + y_spacing) * 11, text_size, Rl::BLACK)
    Rl.draw_text("Shift : Go Faster", x, y + (text_size + y_spacing) * 12, text_size, Rl::BLACK)
    Rl.draw_text("Q : Show Seed #", x, y + (text_size + y_spacing) * 14, text_size, Rl::BLACK)
  end

  def self.draw_seed
    text_size = 20
    seed_text = "#{perlin.seed}"
    seed_text_length = Rl.measure_text(seed_text, text_size)

    color_text = "#{@@color_palette_key}(#{colors.keys.index(@@color_palette_key)})"
    color_text_length = Rl.measure_text(color_text, text_size)

    text_length = (seed_text_length > color_text_length ? seed_text_length : color_text_length)

    x = (screen_width / 2.0) - (text_length / 2.0)
    y = (screen_height * 0.9)
    w = text_length + text_size
    h = text_size * 3

    Rl.draw_rectangle(x - (text_size/2.0), y - (text_size/2.0), w, h, Rl::WHITE)
    Rl.draw_rectangle_lines(x - (text_size/2.0), y - (text_size/2.0), w, h, Rl::BLACK)
    Rl.draw_text(seed_text, (screen_width / 2.0) - (seed_text_length / 2.0), y, text_size, Rl::BLACK)
    Rl.draw_text(color_text, (screen_width / 2.0) - (color_text_length / 2.0), y + text_size + (text_size / 2), text_size, Rl::BLACK)
  end

  # Draw a loading screen.
  def self.draw_loading(percent_done : Float32, text_displayed : String)
    Rl.begin_drawing
    Rl.clear_background(Rl::RAYWHITE)
    Rl.begin_mode_2d(@@camera)

    loading_text = "Loading..."
    text_size = 20
    loading_text_measure = Rl.measure_text(loading_text, text_size)

    Rl.draw_text(loading_text, (screen_width/2.0) - (loading_text_measure/2.0), (screen_height/2.0) - (loading_text_measure/2.0), text_size, Rl::BLACK)
    Rl.draw_rectangle_lines((screen_width/2.0) - (loading_text_measure/2.0), (screen_height/2.0) - (loading_text_measure/2.0) + text_size, loading_text_measure, text_size*2, Rl::BLACK)
    Rl.draw_rectangle((screen_width/2.0) - (loading_text_measure/2.0), (screen_height/2.0) - (loading_text_measure/2.0) + text_size, (loading_text_measure * percent_done), text_size*2, Rl::BLACK)

    text_measure = Rl.measure_text(text_displayed, text_size-2)
    Rl.draw_text(text_displayed, (screen_width/2.0) - (text_measure/2.0), (screen_height/2.0) - (text_measure/2.0), text_size-2, Rl::BLACK)


    Rl.end_mode_2d
    Rl.end_drawing
  end

  def self.run(seed = 1_000_000)
    Rl.init_window(screen_width, screen_height, "Mineshift(#{seed}) @ #{screen_width}x#{screen_height}")
    Rl.set_target_fps(60)

    @@screen_width = Rl.get_monitor_width(MONITOR)
    @@screen_height = Rl.get_monitor_height(MONITOR)
    Rl.set_window_size(screen_width, screen_height)

    Rl.toggle_fullscreen
    sleep 0.1

    Mineshift.setup(seed)

    until Rl.close_window?
      # Determine the Y values for scrolling

      # Change the speed modifier for scrolling when holding the LeftTrigger or LeftShift
      raw_speed_mod = Rl.get_gamepad_axis_movement(CONTROLLER_PORT, Rl::GamepadAxis::LeftTrigger) + (Rl.key_down?(Rl::KeyboardKey::LeftShift) ? SPEED_MODIFIER : 0)
      # If the raw speed mod has a valkue above 0, modify it with the speed modifier.
      speed_mod = (raw_speed_mod > 0 ? (raw_speed_mod + 1) * SPEED_MODIFIER : 1)
      up_arrow_movement = Rl.key_down?(Rl::KeyboardKey::Up) ? -1 : 0
      down_arrow_movement = Rl.key_down?(Rl::KeyboardKey::Down) ? 1 : 0
      mouse_wheel_movement = Rl.get_mouse_wheel_move * -2
      gamepad_movement = Rl.get_gamepad_axis_movement(CONTROLLER_PORT, Rl::GamepadAxis::LeftY)
      @@y_velocity += (gamepad_movement + up_arrow_movement + down_arrow_movement + mouse_wheel_movement) * speed_mod * Y_VELOCITY_DAMPEN
      @@y_velocity *= Y_FRICTION

      @@y_axis_movement += @@y_velocity

      # Determine the x axis movement

      max_x_movement = (screen_width * MAX_X_SCREEN_RATIO)
      gamepad_movement = Rl.get_gamepad_axis_movement(CONTROLLER_PORT, Rl::GamepadAxis::LeftX)
      left_movement = (Rl.key_down?(Rl::KeyboardKey::Left) ? -X_MOVEMENT_FACTOR : 0)
      right_movement = (Rl.key_down?(Rl::KeyboardKey::Right) ? X_MOVEMENT_FACTOR  : 0)
      @@x_axis_position += gamepad_movement * X_MOVEMENT_FACTOR + left_movement + right_movement
      # Clamp x position
      @@x_axis_position = (@@x_axis_position > max_x_movement ? max_x_movement : @@x_axis_position).to_f32
      @@x_axis_position = (@@x_axis_position < -max_x_movement ? -max_x_movement : @@x_axis_position).to_f32

      @@x_axis_position *= X_FRICTION

      Mineshift.draw

      # Randomize the seed when pressing space or A
      if Rl.key_pressed?(Rl::KeyboardKey::Space) || Rl.gamepad_button_pressed?(CONTROLLER_PORT, XBOX_A)
        seed = rand(1_000_000)
        Mineshift.setup(seed)
        Rl.set_window_title("Mineshift(#{seed})")
      end

      # Increment seed when pressing right or RB
      if Rl.key_pressed?(Rl::KeyboardKey::A) || Rl.gamepad_button_pressed?(CONTROLLER_PORT, XBOX_RB)
        seed &+= 1
        Mineshift.setup(seed)
        Rl.set_window_title("Mineshift(#{seed})")
      end

      # Decrement seed when pressing left or LB
      if Rl.key_pressed?(Rl::KeyboardKey::D) || Rl.gamepad_button_pressed?(CONTROLLER_PORT, XBOX_LB)
        seed &-= 1
        Mineshift.setup(seed)
        Rl.set_window_title("Mineshift(#{seed})")
      end

      # Show the seed on the middle of the screen when Q or the RT trigger is held.
      if Rl.key_down?(Rl::KeyboardKey::Q) || (Rl.get_gamepad_axis_movement(CONTROLLER_PORT, Rl::GamepadAxis::RightTrigger) > 0.2)
        Mineshift.show_seed = true
      else
        Mineshift.show_seed = false
      end

      # Show the help screen when pressing tab or B
      if Rl.key_down?(Rl::KeyboardKey::Tab) || Rl.gamepad_button_down?(CONTROLLER_PORT, XBOX_B)
        Mineshift.show_help = true
      else
        Mineshift.show_help = false
      end

      # Decrement palette when pressing O or DPAD Left
      if Rl.key_pressed?(Rl::KeyboardKey::O) || Rl.gamepad_button_pressed?(CONTROLLER_PORT, XBOX_DLEFT)
        _swap_palettes(-1)
      end

      # Increment palette when pressing P or DPAD Right
      if Rl.key_pressed?(Rl::KeyboardKey::P) || Rl.gamepad_button_pressed?(CONTROLLER_PORT, XBOX_DRIGHT)
        _swap_palettes(1)

      end
    end

    Mineshift.destroy

    Rl.close_window
  end
end

Mineshift.run(rand(1_000_000))
