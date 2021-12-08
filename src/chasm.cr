module Mineshift
  module Chasm
    # Makes the center chasm mask for a layer.
    def self.make(layer : UInt8)
      raise "Invalid layer #{layer}" unless layer < Layer::MAX

      # zero out layer
      output = [] of Rl::Rectangle
      center = (Mineshift.screen_width/2).to_i
      current_height = 0
      # Perlin counter (provides random values by increasing seed)
      p_counter = 1

      until current_height > Layer.height(layer)
        mask_rect = Rl::Rectangle.new

        additional_block_spacing = Mineshift.perlin.prng_int(
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
          Mineshift.perlin.int(
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

    def self.draw(chasm_rects)
      # Draw the center chasm mask
      chasm_rects.each do |rect|
        Rl.draw_rectangle_rec(rect, Rl::BLACK)
      end
    end
  end
end
