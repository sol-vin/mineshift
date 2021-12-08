require "raylib-cr"
require "perlin_noise"

require "./seeds"
require "./bridge"
require "./beam"
require "./layer"
require "./window"
require "./rope"

require "./colors"

alias Rl = LibRaylib

module Mineshift
  # TODO: Actually implement this lol!
  # Debug mode on or off
  DEBUG = true
  MONITOR = 0
  Y_FRICTION = 0.9

  X_MOVEMENT_FACTOR = 10
  MAX_X_SCREEN_RATIO = 0.04

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

  # How much should we upscale/downscale the image
  class_property scale_ratio = 1.0
  # The virtual screen width
  class_property virtual_screen_width : Int32 = (1280/scale_ratio).to_i
  # The virtual screen height
  class_property virtual_screen_height : Int32 = (1024/scale_ratio).to_i
  # How many `virtual_screen_height`s high we should make the final texture. If set to `1.0` it will only reapeat one screen's worth of content.
  class_property height_multiplier = 8
  # Should we show the seed number in a tasteful little white box?
  class_property? show_seed = false
  # Should we show the help in a white box?
  class_property? show_help = false

  # Our RNGesus
  class_getter perlin = PerlinNoise.new(1_000_000)

  # WHat color pallette we are using
  @@color_palette : Array(Rl::Color) = [] of Rl::Color
  @@color_palette_key : Symbol = :none

  # How much the y axis should be scrolled by. Changed by moving the analog stick or pressing up or down.
  @@y_axis_movement = 0.0_f32
  @@y_velocity = 0.0_f32

  @@x_axis_position = 0.0_f32

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

  # The ratio of `virtual_screen_width` to `virtual_screen_height`
  private def self._virtual_screen_ratio
    virtual_screen_width/virtual_screen_height
  end

  # Actual window width
  private def self._screen_width
    virtual_screen_width * scale_ratio
  end

  # Actual window height
  private def self._screen_height
    virtual_screen_height * scale_ratio
  end


  # Makes the center chasm mask for a layer.
  private def self._make_chasm_rects(layer : UInt8)
    raise "Invalid layer #{layer}" unless layer < Layer::MAX

    # zero out layer
    output = [] of Rl::Rectangle
    center = (@@virtual_screen_width/2).to_i
    current_height = 0
    # Perlin counter (provides random values by increasing seed)
    p_counter = 1

    until current_height > Layer.height(layer)
      mask_rect = Rl::Rectangle.new

      additional_block_spacing = @@perlin.prng_int(
        p_counter,
        current_height,
        layer + 1,
        0,
        Layer::DATA[layer][:max_blocks],
        Seeds::BLOCK_SPACING) * Layer::DATA[layer][:block_size]
      mask_rect.width = Layer::DATA[layer][:max_distance] - additional_block_spacing
      mask_rect.height = Layer::DATA[layer][:block_size] + 1 # Offset by one because of svg antialiasing issues

      position_x = center - (mask_rect.width/2).to_i
      deviation =
        @@perlin.int(
          current_height,
          p_counter,
          layer + 1,
          -Layer::DATA[layer][:deviation],
          Layer::DATA[layer][:deviation],
          Seeds::CENTER_MASK_DEVIATION
        )

      deviation *= Layer::DATA[layer][:block_size]
      mask_rect.y = current_height - 1 # Offset by one to ensure overlap
      mask_rect.x = position_x - deviation
      current_height += Layer::DATA[layer][:block_size]
      p_counter += 1

      output << mask_rect
    end
    output
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
    render_texture = Rl.load_render_texture(@@virtual_screen_width, Layer.height(layer))

    Rl.begin_texture_mode(render_texture)
    Rl.clear_background(Rl::WHITE)
    Rl.begin_mode_2d(@@camera)

    chasm_rects = _make_chasm_rects(layer)

    # Draw the center chasm mask
    chasm_rects.each do |rect|
      Rl.draw_rectangle_rec(rect, Rl::BLACK)
    end

    bridge_rects = [] of Rl::Rectangle
    if layer < Bridge::LAYER
      bridge_rects = Bridge.make(layer, chasm_rects)
    end

    beam_rects = [] of Rl::Rectangle
    if layer > Beam::LAYER
      beam_rects = Beam.make(layer, chasm_rects)
    end

    window_rects = Window.make(layer, chasm_rects)


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

  # Swaps the palettes by converting to an image and then back to a texture
  private def self._swap_palettes(pallete_offset)
    old_palette = @@color_palette
    
    index = 0
    if index = colors.keys.index(@@color_palette_key)
      index += pallete_offset
      index %= colors.keys.size
      index = colors.keys.size if index < 0
      
      @@color_palette_key = colors.keys[index]
    end
    @@color_palette = colors[@@color_palette_key]
  end

  # Draw the scene
  def self.draw
    Rl.begin_drawing
    Rl.clear_background(@@color_palette[0])
    Rl.begin_mode_2d(@@camera)

    # Draw each layer
    Layer::MAX.times do |layer|
      # Offset it because for some reason there is "perlin striping" showing similarities in the different  layers
      layer_offset = 10.0/scale_ratio + ((5.0 / scale_ratio) * ((layer + 1) ** layer) * (@@y_axis_movement * 0.05))
      x = @@x_axis_position * (layer+1)
      y = -layer_offset

      # Draw the texture so when scrolling it will move the y of the source rect, causing the texture to repeat.
      Rl.draw_texture_pro(
        @@textures[layer],
        Rl::Rectangle.new(x: x, y: y, width: @@virtual_screen_width, height: -@@virtual_screen_height),
        Rl::Rectangle.new(x: 0, y: 0, width: _screen_width, height: _screen_height),
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

  def self.draw_help
    text_size = 20
    y_spacing = 5
    title = "#{"   " * 10}HELP#{"   " * 10}"
    text_length = Rl.measure_text(title, text_size)

    x = (_screen_width / 2.0) - (text_length/2.0)
    y = (_screen_height * 0.3)
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

    x = (_screen_width / 2.0) - (text_length / 2.0)
    y = (_screen_height * 0.9)
    w = text_length + text_size
    h = text_size * 3

    Rl.draw_rectangle(x - (text_size/2.0), y - (text_size/2.0), w, h, Rl::WHITE)
    Rl.draw_rectangle_lines(x - (text_size/2.0), y - (text_size/2.0), w, h, Rl::BLACK)
    Rl.draw_text(seed_text, (_screen_width / 2.0) - (seed_text_length / 2.0), y, text_size, Rl::BLACK)
    Rl.draw_text(color_text, (_screen_width / 2.0) - (color_text_length / 2.0), y + text_size + (text_size / 2), text_size, Rl::BLACK)
  end

  # Draw a loading screen.
  def self.draw_loading(percent_done : Float32, text_displayed : String)
    Rl.begin_drawing
    Rl.clear_background(Rl::RAYWHITE)
    Rl.begin_mode_2d(@@camera)

    loading_text = "Loading..."
    text_size = 20
    loading_text_measure = Rl.measure_text(loading_text, text_size)

    Rl.draw_text(loading_text, (_screen_width/2.0) - (loading_text_measure/2.0), (_screen_height/2.0) - (loading_text_measure/2.0), text_size, Rl::BLACK)
    Rl.draw_rectangle_lines((_screen_width/2.0) - (loading_text_measure/2.0), (_screen_height/2.0) - (loading_text_measure/2.0) + text_size, loading_text_measure, text_size*2, Rl::BLACK)
    Rl.draw_rectangle((_screen_width/2.0) - (loading_text_measure/2.0), (_screen_height/2.0) - (loading_text_measure/2.0) + text_size, (loading_text_measure * percent_done), text_size*2, Rl::BLACK)

    text_measure = Rl.measure_text(text_displayed, text_size-2)
    Rl.draw_text(text_displayed, (_screen_width/2.0) - (text_measure/2.0), (_screen_height/2.0) - (text_measure/2.0), text_size-2, Rl::BLACK)


    Rl.end_mode_2d
    Rl.end_drawing
  end

  def self.run(seed = 1_000_000)
    Rl.init_window(_screen_width, _screen_height, "Mineshift(#{seed})")
    Rl.set_target_fps(60)

    Rl.toggle_fullscreen
    sleep 0.1

    Rl.set_window_size(Rl.get_monitor_width(MONITOR), Rl.get_monitor_height(MONITOR))
    @@virtual_screen_width = (Rl.get_monitor_width(MONITOR)/scale_ratio).to_i
    @@virtual_screen_height = (Rl.get_monitor_height(MONITOR)/scale_ratio).to_i

    Mineshift.setup(seed)

    until Rl.close_window?
      # Change the speed modifier for scrolling when holding the LeftTrigger
      raw_speed_mod = Rl.get_gamepad_axis_movement(0, Rl::GamepadAxis::LeftTrigger) + (Rl.key_down?(Rl::KeyboardKey::LeftShift) ? 2 : 0)
      speed_mod = (raw_speed_mod > 0 ? (raw_speed_mod + 1) * 2.0 : 1)
      up_arrow_movement = Rl.key_down?(Rl::KeyboardKey::Up) ? -1 : 0
      down_arrow_movement = Rl.key_down?(Rl::KeyboardKey::Down) ? 1 : 0
      @@y_velocity += ((Rl.get_gamepad_axis_movement(0, Rl::GamepadAxis::LeftY) + up_arrow_movement + down_arrow_movement + (Rl.get_mouse_wheel_move * -2)) * speed_mod) * 0.25
      @@y_velocity *= Y_FRICTION

      @@y_axis_movement += @@y_velocity

      max_x_movement = (virtual_screen_width * MAX_X_SCREEN_RATIO)

      @@x_axis_position += Rl.get_gamepad_axis_movement(0, Rl::GamepadAxis::LeftX) * X_MOVEMENT_FACTOR + (Rl.key_down?(Rl::KeyboardKey::Left) ? -X_MOVEMENT_FACTOR : 0) + (Rl.key_down?(Rl::KeyboardKey::Right) ? X_MOVEMENT_FACTOR  : 0)
      # Clamp x position
      @@x_axis_position = (@@x_axis_position > max_x_movement ? max_x_movement : @@x_axis_position).to_f32
      @@x_axis_position = (@@x_axis_position < -max_x_movement ? -max_x_movement : @@x_axis_position).to_f32

      @@x_axis_position *= 0.9

      Mineshift.draw

      # Randomize the seed when pressing space or A
      if Rl.key_pressed?(Rl::KeyboardKey::Space) || Rl.gamepad_button_pressed?(0, 7)
        seed = rand(1_000_000)
        Mineshift.setup(seed)
        Rl.set_window_title("Mineshift(#{seed})")
      end

      # Increment seed when pressing right or RB
      if Rl.key_pressed?(Rl::KeyboardKey::A) || Rl.gamepad_button_pressed?(0, 11)
        seed &+= 1
        Mineshift.setup(seed)
        Rl.set_window_title("Mineshift(#{seed})")
      end

      # Decrement seed when pressing left or LB
      if Rl.key_pressed?(Rl::KeyboardKey::D) || Rl.gamepad_button_pressed?(0, 9)
        seed &-= 1
        Mineshift.setup(seed)
        Rl.set_window_title("Mineshift(#{seed})")
      end

      # Show the seed on the middle of the screen when Q or the RT trigger is held.
      if Rl.key_down?(Rl::KeyboardKey::Q) || (Rl.get_gamepad_axis_movement(0, Rl::GamepadAxis::RightTrigger) > 0.5)
        Mineshift.show_seed = true
      else
        Mineshift.show_seed = false
      end

      if Rl.key_down?(Rl::KeyboardKey::Tab) || Rl.gamepad_button_down?(0, 6)
        Mineshift.show_help = true
      else
        Mineshift.show_help = false
      end

      if Rl.key_pressed?(Rl::KeyboardKey::O) || Rl.gamepad_button_pressed?(0, 4)
        _swap_palettes(-1)
      end

      if Rl.key_pressed?(Rl::KeyboardKey::P) || Rl.gamepad_button_pressed?(0, 2)
        _swap_palettes(1)

      end
    end

    Mineshift.destroy

    Rl.close_window
  end
end

Mineshift.run(rand(1_000_000))
