module Mineshift
  module Rope
    MIN_LENGTH = 0.5
    MIN_THICKNESS = 3
    MAX_MOVES = 30

    EXISTS_CHANCE = 1
    EXISTS_OUT_OF = 10

    def self.exists?(rope, layer)
      Mineshift.perlin.prng_int(rope[0].x.to_i, rope[0].y.to_i, layer.to_i, 0, EXISTS_OUT_OF, Seeds::ROPE) < EXISTS_CHANCE
    end

    def self.length(rope, layer, min, max)
      Mineshift.perlin.prng_int(rope[0].x.to_i, rope[0].y.to_i, layer.to_i, min, max, Seeds::ROPE_LENGTH)
    end

    def self.thickness(rope, layer)
      Mineshift.perlin.prng_int(rope[0].x.to_i, rope[0].y.to_i, layer.to_i, Rope::MIN_THICKNESS, (layer.to_i*3)-1, Seeds::ROPE_THICKNESS)
    end

    def self.make(layer, chasm_rects, beam_rects)
      rope_points = [] of Array(Rl::Vector2)
      inverted_chasm_rects = chasm_rects.map do |r|
        left = Rl::Rectangle.new(
          x: 0,
          y: r.y,
          width: r.x,
          height: r.height
        )
        right = Rl::Rectangle.new(
          x: r.x + r.width,
          y: r.y,
          width: Mineshift.virtual_screen_width - (r.x + r.width),
          height: r.height
        )
  
        [left, right]
      end.flatten
  
      collision_rects = inverted_chasm_rects + beam_rects
  
      rope_segment_length = Layer::DATA[layer][:block_size]*0.2
  
  
      collision_rects.each do |c_rect|
        rope_x = c_rect.x + Layer::DATA[layer][:block_size]
        rect_bottom = c_rect.y + c_rect.height - 1
        until rope_x > (c_rect.x + c_rect.width - Layer::DATA[layer][:block_size])
          rope_y = rect_bottom
          moves = 0
          until moves > MAX_MOVES || rope_y > Layer.height(layer) || collision_rects.any?{|r| Rl.check_collision_point_rec?(Rl::Vector2.new(x: rope_x, y: rope_y + rope_segment_length), r)}
            rope_y += rope_segment_length
            moves += 1
          end
  
          if moves > 0
            rope_points << [Rl::Vector2.new(x: rope_x, y: rect_bottom), Rl::Vector2.new(x: rope_x, y: rope_y)]
          end
  
          rope_x += rope_segment_length
        end
      end
  
      rope_points.each do |rope|
        if exists?(rope, layer)
          max_length = (rope[1].y - rope[0].y).to_i
          min_length = (max_length * MIN_LENGTH).to_i
          length = length(rope, layer, min_length, max_length)
          thickness = thickness(rope, layer)
  
          Rl.draw_line_ex(rope[0], Rl::Vector2.new(x: rope[0].x, y: rope[0].y + length), thickness, Rl::WHITE)
        end
      end
    end
  end
end