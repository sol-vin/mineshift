module Mineshift
  module Beam
    LAYER = 1
    # Minimum ratio of block size to beam height
    MIN_RATIO = 0.1
    # Maximum ratio of block size to beam height
    MAX_RATIO = 0.5

    MIN_HEIGHT_RATIO = 0.20
    MAX_HEIGHT_RATIO = 0.70

    CHANCE = 5

    # Make metal beams on layers 2 and 3.
    def self.make(layer, chasm_rects)
      # Bounding boxes of the beams, used for collision detection later.
      beam_bounding_boxes = [] of Rl::Rectangle

      # Only draw on layers 2 and 3
      if layer > 1
        # Go through each potential beam location
        chasm_rects.each_with_index do |rect, rect_index|
          # Should we draw a beam here?
          if Mineshift.perlin.prng_int(layer, rect_index, 0, Beam::CHANCE, Seeds::BEAM) == 0
            # How should the beam be positioned? Left or right?
            beam_side = Mineshift.perlin.prng_item(layer, rect_index, [true, false], Seeds::BEAM_SIDE) ? :left : :right

            # Determine the starting point for the beam.
            beam_point = Rl::Vector2.new
            if beam_side == :left
              beam_point.x = rect.x
              beam_point.y = rect.y + rect.height/2.0
            elsif beam_side == :right
              beam_point.x = rect.x + rect.width
              beam_point.y = rect.y + rect.height/2.0
            end

            # Beam height parameters and choose a beam height.
            min_beam_height = (Layer::DATA[layer][:block_size]*Beam::MIN_HEIGHT_RATIO).to_i
            max_beam_height = (Layer::DATA[layer][:block_size]*Beam::MAX_HEIGHT_RATIO).to_i
            beam_height = Mineshift.perlin.prng_int(layer, rect_index, min_beam_height, max_beam_height, Seeds::BEAM_HEIGHT)

            # Number of segments a beam should have.
            min_segments = ((rect.width*Beam::MIN_RATIO/beam_height)).to_i
            max_segments = ((rect.width*Beam::MAX_RATIO/beam_height)).to_i
            segments = Mineshift.perlin.prng_int(layer.to_i, rect_index, min_beam_height, max_beam_height, Seeds::BEAM_SEGMENTS)

            # Should the top or bottom be short?
            beam_short_side = Mineshift.perlin.prng_item(layer, rect_index, [true, false], Seeds::BEAM_SHORT_SIDE) ? :top : :bottom

            # The beam point is directly in the middle, so offset it up to where it should be
            beam_point.y -= beam_height/2.0

            # Figure out the points for the beam
            left_top = Rl::Vector2.new
            right_top = Rl::Vector2.new
            left_bot = Rl::Vector2.new
            right_bot = Rl::Vector2.new

            if beam_short_side == :top
              if beam_side == :left
                left_top = beam_point
                right_top = Rl::Vector2.new(x: beam_point.x + (beam_height * segments), y: beam_point.y)
                left_bot = Rl::Vector2.new(x: beam_point.x, y: beam_point.y + beam_height)
                right_bot = Rl::Vector2.new(x: beam_point.x + (beam_height * (segments - 1)), y: beam_point.y + beam_height)
              elsif beam_side == :right
                left_top = Rl::Vector2.new(x: beam_point.x - (beam_height * segments), y: beam_point.y)
                right_top = beam_point
                left_bot = Rl::Vector2.new(x: beam_point.x - (beam_height * (segments - 1)), y: beam_point.y + beam_height)
                right_bot = Rl::Vector2.new(x: beam_point.x, y: beam_point.y + beam_height)
              end
            elsif beam_short_side == :bottom
              if beam_side == :left
                left_top = beam_point
                right_top = Rl::Vector2.new(x: beam_point.x + (beam_height * (segments - 1)), y: beam_point.y)
                left_bot = Rl::Vector2.new(x: beam_point.x, y: beam_point.y + beam_height)
                right_bot = Rl::Vector2.new(x: beam_point.x + (beam_height * segments), y: beam_point.y + beam_height)
              elsif beam_side == :right
                left_top = Rl::Vector2.new(x: beam_point.x - (beam_height * (segments - 1)), y: beam_point.y)
                right_top = beam_point
                left_bot = Rl::Vector2.new(x: beam_point.x - (beam_height * segments), y: beam_point.y + beam_height)
                right_bot = Rl::Vector2.new(x: beam_point.x, y: beam_point.y + beam_height)
              end
            end

            # Minimum line thickness for the beam
            # TODO: This is stinky fix pls
            min_thickness = 3.ceil.to_i - (layer == 2 ? 1 : 0)

            beam_height_ratio = beam_height / max_beam_height

            # Choose a line thickness
            thickness = Mineshift.perlin.prng_int(layer, rect_index, min_thickness, min_thickness + 1 + (min_thickness * beam_height_ratio).to_i, Seeds::BEAM_THICKNESS)

            # Check if the beam properly intersects all points of the chasm rectangle, and ensure the beam isn't too long.
            if [left_top, right_top, left_bot, right_bot].all? { |v| Rl.check_collision_point_rec?(v, rect) } && ((right_bot.x - left_bot.x)/rect.width < Beam::MAX_RATIO)
              if beam_short_side == :top
                if beam_side == :left
                  beam_bounding_boxes << Rl::Rectangle.new(x: left_top.x, y: left_top.y, width: right_top.x - left_top.x, height: left_bot.y - left_top.y)
                elsif beam_side == :right
                  beam_bounding_boxes << Rl::Rectangle.new(x: left_top.x, y: left_top.y, width: right_top.x - left_top.x, height: left_bot.y - left_top.y)
                end
              elsif beam_short_side == :bottom
                if beam_side == :left
                  beam_bounding_boxes << Rl::Rectangle.new(x: left_top.x, y: left_top.y, width: right_bot.x - left_top.x, height: left_bot.y - left_top.y)
                elsif beam_side == :right
                  beam_bounding_boxes << Rl::Rectangle.new(x: left_bot.x, y: left_top.y, width: right_bot.x - left_bot.x, height: left_bot.y - left_top.y)
                end
              end
              # Draw the outline
              Rl.draw_line_ex(left_top, right_top, thickness, Rl::WHITE)
              Rl.draw_line_ex(right_bot, right_top, thickness, Rl::WHITE)
              Rl.draw_line_ex(left_bot, right_bot, thickness, Rl::WHITE)
              Rl.draw_line_ex(left_top, left_bot, thickness, Rl::WHITE)

              # Fix the line caps (they are straight, we need circles)
              Rl.draw_circle_v(left_top, thickness/2, Rl::WHITE)
              Rl.draw_circle_v(right_top, thickness/2, Rl::WHITE)
              Rl.draw_circle_v(right_bot, thickness/2, Rl::WHITE)
              Rl.draw_circle_v(left_bot, thickness/2, Rl::WHITE)

              # Draw the struts
              # true: draw stroke from top to bottom, false: draw stroke from bottom to top
              mirror = true
              current_point = Rl::Vector2.new

              # Set up the point and mirroring where it needs to be.
              if beam_short_side == :top
                if beam_side == :left
                  current_point = right_top
                elsif beam_side == :right
                  current_point = left_top
                end
              elsif beam_short_side == :bottom
                mirror = false # draw bottom to top
                if beam_side == :left
                  current_point = right_bot
                elsif beam_side == :right
                  current_point = left_bot
                end
              end

              # Walk the struct lines
              segments.times do
                if mirror
                  if beam_side == :left
                    new_point = Rl::Vector2.new(x: current_point.x - beam_height, y: current_point.y + beam_height)
                    Rl.draw_line_ex(current_point, new_point, thickness, Rl::WHITE)
                    current_point = new_point
                  elsif beam_side == :right
                    new_point = Rl::Vector2.new(x: current_point.x + beam_height, y: current_point.y + beam_height)
                    Rl.draw_line_ex(current_point, new_point, thickness, Rl::WHITE)
                    current_point = new_point
                  end
                else
                  if beam_side == :left
                    new_point = Rl::Vector2.new(x: current_point.x - beam_height, y: current_point.y - beam_height)
                    Rl.draw_line_ex(current_point, new_point, thickness, Rl::WHITE)
                    current_point = new_point
                  elsif beam_side == :right
                    new_point = Rl::Vector2.new(x: current_point.x + beam_height, y: current_point.y - beam_height)
                    Rl.draw_line_ex(current_point, new_point, thickness, Rl::WHITE)
                    current_point = new_point
                  end
                end

                mirror = !mirror
              end
            end
          end
        end
      end
      # Unmeltable by any jet fuel.
      beam_bounding_boxes
    end
  end
end