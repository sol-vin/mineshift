  module Mineshift
  # Layer data and information.
  module Layer
    # How many max layers
    MAX = 4
    # Scaling constants for each layer
    SIZES = {
      0 => 0.02,
      1 => 0.04,
      2 => 0.06,
      3 => 0.08,
    }

    # The layer data including max distance, max blocks, block size, deviation, and how much the window's should be padded.
    DATA = {
      0 => {
        max_distance:   ((Mineshift.screen_width/2)*SIZES[0]).to_i * 10,
        max_blocks:     4,
        block_size:     ((Mineshift.screen_width/2)*SIZES[0]).to_i,
        deviation:      4,
      },

      1 => {
        max_distance:   ((Mineshift.screen_width/2)*SIZES[1]).to_i * 12,
        max_blocks:     3,
        block_size:     ((Mineshift.screen_width/2)*SIZES[1]).to_i,
        deviation:      2,
      },

      2 => {
        max_distance:   ((Mineshift.screen_width/2)*SIZES[2]).to_i * 16,
        max_blocks:     3,
        block_size:     ((Mineshift.screen_width/2)*SIZES[2]).to_i,
        deviation:      3,
      },

      3 => {
        max_distance:   ((Mineshift.screen_width/2)*SIZES[3]).to_i * 20,
        max_blocks:     7,
        block_size:     ((Mineshift.screen_width/2)*SIZES[3]).to_i,
        deviation:      2,
      },
    }

    # The height of the texture for a layer in blocks. Prevents "seams" bug
    def self.blocks_high(layer)
      ((Mineshift.screen_height * Mineshift.height_multiplier)/DATA[layer][:block_size]).floor
    end

    # The height of the texture for a layer. Prevents "seams" bug
    def self.height(layer)
      (blocks_high(layer) * DATA[layer][:block_size]).floor - 1
    end
  end
end