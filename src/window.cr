module Mineshift
  # Window information
  module Window
    # Chance to spawn a window
    EXIST_CHANCE = 2
    # Chance to spawn a window out of how many total?
    EXIST_OUT_OF = 5

    STRUT_CHANCE = 1
    STRUT_OUT_OF = 4

    CENTER_CHANCE = 1
    CENTER_OUT_OF = 4
    
    OUTER_WINDOW_TYPES = [:square, :circle]

    INNER_MIN_PARTS = 2
    INNER_MAX_PARTS = 4

    INNER_CENTER_TYPES = [:square, :circle]

    RATIO = 2.0

    PADDING_RATIO = 0.2

    SUBDIVIDE_CHANCE = 7
    SUBDIVIDE_CHANCE_OUT_OF = 10

    # All the windows made into procs that take a x, y, w, h value and fits the window in that rectangle.
    ALL = [
      # Regular window
      ->(layer : UInt8, x : Float32, y : Float32, w : Float32, h : Float32) {
        # Make the padding
        padding = w * PADDING_RATIO

        # What kind of outer window should we draw?
        outer_window_type = Mineshift.perlin.prng_item(x.to_i, y.to_i, layer.to_i, OUTER_WINDOW_TYPES, Seeds::OUTER_WINDOW)
        if outer_window_type == :circle
          Rl.draw_circle(x + w / 2.0, y + h / 2.0, (w/2.0) - padding, Rl::BLACK)
        elsif outer_window_type == :square
          r = Rl::Rectangle.new(
            x: x + padding,
            y: y + padding,
            width: w - (padding*2.0),
            height: h - (padding*2.0)
          )
          Rl.draw_rectangle_rec(r, Rl::BLACK)
        end

        has_window_struts = has_window_struts?(x, y, layer)
        number_of_strut_parts = number_of_strut_parts(x, y, layer)


        if has_window_struts
          thickness = w * 0.1
          parts = [
            ->(x : Float32, y : Float32, r : Float32) {
              Rl.draw_line_ex(Rl::Vector2.new(x: x - (thickness/2.0), y: y), Rl::Vector2.new(x: x + r , y: y), thickness, Rl::WHITE)
            },

            ->(x : Float32, y : Float32, r : Float32) {
              Rl.draw_line_ex(Rl::Vector2.new(x: x + (thickness/2.0), y: y), Rl::Vector2.new(x: x - r, y: y), thickness, Rl::WHITE)
            },

            ->(x : Float32, y : Float32, r : Float32) {
              Rl.draw_line_ex(Rl::Vector2.new(x: x, y: y - (thickness/2.0)), Rl::Vector2.new(x: x, y: y + r), thickness, Rl::WHITE)
            },

            ->(x : Float32, y : Float32, r : Float32) {
              Rl.draw_line_ex(Rl::Vector2.new(x: x, y: y + (thickness/2.0)), Rl::Vector2.new(x: x, y: y - r), thickness, Rl::WHITE)
            }
          ] of Proc(Float32, Float32, Float32, Nil)


          number_of_strut_parts.times do |z|
            part_index = Mineshift.perlin.prng_int(x.to_i, y.to_i, z, 0, parts.size, Seeds::WINDOW_STRUT_PARTS)

            parts[part_index].call(x + w / 2.0, y + h / 2.0, (w / 2.0).to_f32)
            parts.delete_at(part_index)
          end
        end

        has_window_center = has_window_center?(x, y, layer)
        if has_window_center
          Rl.draw_circle_v(Rl::Vector2.new(x: x + w / 2.0, y: y + h / 2.0), (w/3.0) - padding, Rl::WHITE)
        end
      },

    ] of Proc(UInt8, Float32, Float32, Float32, Float32, Nil)

    def self.should_window_subdivide?(rect : Rl::Rectangle, pass : Int, layer : UInt8)
      Mineshift.perlin.prng_int(rect.x.to_i, rect.y.to_i, (pass+1) * (layer+1), 0, SUBDIVIDE_CHANCE_OUT_OF, Seeds::WINDOW_SUBDIVIDE) < SUBDIVIDE_CHANCE
    end

    def self.should_window_exist?(rect : Rl::Rectangle, layer : UInt8)
      Mineshift.perlin.int(rect.x.to_i, rect.y.to_i, ((layer.to_i+1) ** (layer.to_i+1)), 0, EXIST_OUT_OF, Seeds::WINDOW_EXIST) < EXIST_CHANCE
    end

    def self.make_window(rect : Rl::Rectangle, layer : UInt8)
      Mineshift.perlin.prng_item(rect.x.to_i, rect.y.to_i, (layer&+1), ALL, Seeds::WINDOW_TYPE).call layer, rect.x, rect.y, rect.width, rect.height
    end

    def self.has_window_struts?(x, y, layer)
      Mineshift.perlin.prng_int(x.to_i, y.to_i, layer.to_i, 0, STRUT_OUT_OF, Seeds::WINDOW_STRUT) < STRUT_CHANCE
    end

    def self.number_of_strut_parts(x, y, layer)
      Mineshift.perlin.prng_int(x.to_i, y.to_i, layer.to_i, Window::INNER_MIN_PARTS.to_i, Window::INNER_MAX_PARTS.to_i + 1, Seeds::WINDOW_STRUT_PARTS_NUMBER)
    end

    def self.has_window_center?(x, y, layer)
      has_window_struts = has_window_struts?(x, y, layer)
      number_of_strut_parts = number_of_strut_parts(x, y, layer)
      (Mineshift.perlin.prng_int(x.to_i, y.to_i, layer.to_i, 0, CENTER_OUT_OF, Seeds::WINDOW_CENTER) < CENTER_CHANCE) && (!has_window_struts || (has_window_struts && number_of_strut_parts != 2))
    end

    def self.make(layer, chasm_rects)
      window_bounding_boxes = [] of Rl::Rectangle

      # Largest possible window
      max_window_frame = Rl::Rectangle.new(
        x: 0,
        y: 0,
        width: Layer::DATA[layer][:block_size] * RATIO,
        height: Layer::DATA[layer][:block_size] * RATIO
      )

      subdivided_squares = [] of Rl::Rectangle

      frame_rect = max_window_frame
      until (frame_rect.y + frame_rect.height) >= Layer.height(layer)
        frame_rect.x = 0
        # Check if frame_rects collide,
        until chasm_rects.any? { |r| Rl.check_collision_recs?(frame_rect, r) }
          raise "Something went wrong, frame_rect should collide before this happens" if frame_rect.x > Mineshift.virtual_screen_width
          subdivided_squares << frame_rect
          frame_rect.x += frame_rect.width
        end

        frame_rect.y += frame_rect.height
      end

      frame_rect = max_window_frame
      until (frame_rect.y + frame_rect.height) >= Layer.height(layer)
        frame_rect.x = Mineshift.virtual_screen_width - frame_rect.width
        # Check if frame_rects collide,
        until chasm_rects.any? { |r| Rl.check_collision_recs?(frame_rect, r) }
          raise "Something went wrong, frame_rect should collide before this happens" if frame_rect.x < 0
          subdivided_squares << frame_rect
          frame_rect.x -= frame_rect.width
        end

        frame_rect.y += frame_rect.height
      end
      passes = 0
      passes = 1 if layer == 1
      passes = 2 if layer == 2
      passes = 2 if layer == 3

      passes.times do |pass|
        subdivided_squares = subdivided_squares.map do |square|
          if should_window_subdivide?(square, pass, layer)
            width = square.width/2.0

            [
              Rl::Rectangle.new(
                x: square.x,
                y: square.y,
                width: width,
                height: width
              ),

              Rl::Rectangle.new(
                x: square.x + width,
                y: square.y,
                width: width,
                height: width
              ),

              Rl::Rectangle.new(
                x: square.x + width,
                y: square.y + width,
                width: width,
                height: width
              ),

              Rl::Rectangle.new(
                x: square.x,
                y: square.y + width,
                width: width,
                height: width
              ),
            ]
          else
            square
          end
        end.flatten
      end

      subdivided_squares.each_with_index do |rect|
        if should_window_exist?(rect, layer)
          make_window(rect, layer)
          window_bounding_boxes << rect
        end
      end

      window_bounding_boxes
    end
  end
end