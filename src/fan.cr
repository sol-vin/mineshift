module Mineshift
  # Couldn't get this to work :(
  module Fan
    SIZE = 128
    CENTER = SIZE/2

    CENTER_CIRCLE_RADIUS = SIZE*0.15

    EXISTS_CHANCE = 1
    EXISTS_OUT_OF = 3

    class_property texture : Rl::Texture2D = Rl::Texture2D.new
    class_property spin_time = 0.0

    def self.exists?(rect : Rl::Rectangle,)
      Mineshift.perlin.prng_int(rect.x.to_i, rect.y.to_i, 0, EXISTS_OUT_OF, Seeds::FAN_EXISTS) < EXISTS_CHANCE
    end

    def self.make_texture
      petal_render = Rl.load_render_texture(SIZE, SIZE)
      fan_render = Rl.load_render_texture(SIZE, SIZE)

      Rl.begin_texture_mode(petal_render)
      Rl.clear_background(Rl::BLACK)
      Rl.begin_mode_2d(Mineshift.camera)

      center = SIZE/2.0
      petal_width = SIZE/12.0
      petal_height = SIZE/5

      Rl.draw_ellipse(center, center + center/2.0, petal_width, petal_height, Rl::WHITE)

      Rl.end_mode_2d
      Rl.end_texture_mode

      # Make an image out of our render texture
      image = Rl.load_image_from_texture(petal_render.texture)

      # Replace the color black with transparency
      Rl.image_color_replace(pointerof(image), Rl::BLACK, Rl::Color.new(r: 0_u8, g: 0_u8, b: 0_u8, a: 0_u8))

      petal = Rl.load_texture_from_image(image)

      Rl.begin_texture_mode(fan_render)
      Rl.clear_background(Rl::BLACK)
      Rl.begin_mode_2d(Mineshift.camera)

      5.times do |x|
        origin = Rl::Vector2.new(x: CENTER, y: CENTER)
        Rl.draw_texture_pro(
          petal,
          Rl::Rectangle.new(x: 0, y: 0, width: SIZE, height: SIZE),
          Rl::Rectangle.new(x: CENTER, y: CENTER, width: SIZE, height: SIZE),
          origin,
          x * (360/5.0),
          Rl::WHITE
        )
      end

      Rl.draw_circle(CENTER, CENTER, CENTER_CIRCLE_RADIUS, Rl::WHITE)

      Rl.end_mode_2d
      Rl.end_texture_mode

      # Make an image out of our render texture
      image = Rl.load_image_from_texture(fan_render.texture)

      # Replace the color black with transparency
      Rl.image_color_replace(pointerof(image), Rl::BLACK, Rl::Color.new(r: 0_u8, g: 0_u8, b: 0_u8, a: 0_u8))
      #Reload the texture from the image
      @@texture = Rl.load_texture_from_image(image)

      # Clean up the old data
      Rl.unload_image(image)
      Rl.unload_render_texture(petal_render)
      Rl.unload_render_texture(fan_render)
      Rl.unload_texture(petal)
    end

    def self.draw(x, y, size, color)
      Rl.draw_texture_pro(
        texture,
        Rl::Rectangle.new(x:0, y: 0, width: Fan::SIZE, height: Fan::SIZE),
        Rl::Rectangle.new(x: x, y: y, width: size, height: size),
        Rl::Vector2.new(x: size/2.0, y: size/2.0),
        spin_time,
        color
      )
    end

    def self.select_windows(windows : Array(Rl::Rectangle))
      windows.select {|x| exists? x}
    end

    def self.draw_all(windows : Array(Rl::Rectangle), offset, color)
      windows.each do |window|
        if exists?(window)
          fan_height = window.height*0.7
          draw(window.x + window.height/2.0 + offset.x, window.y + window.height/2.0 + offset.y, fan_height, color)
        end
      end
    end
  end
end