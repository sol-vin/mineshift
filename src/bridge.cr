module Mineshift
  module Bridge
    LAYER = 2
    MAX_ANGLE = 30
    MIN_HEIGHT_RATIO = 0.20
    MAX_HEIGHT_RATIO = 0.75
    COLLISION_SEGMENT_RATIO = 0.08

    # Makes bridges on layers 0 and 1
    def self.make(layer, chasm_rects)
      bridge_bounding_boxes = [] of Rl::Rectangle
      bridge_paths = [] of Array(Rl::Vector2)
      chasm_rects.each_with_index do |rect, rect_index|
        mask_center_point = Rl::Vector2.new(x: rect.x + rect.width/2.0_f32, y: rect.y + rect.height/2.0_f32)
        bridge_angle = Mineshift.perlin.prng_int(layer, rect_index, -Bridge::MAX_ANGLE, Bridge::MAX_ANGLE, Seeds::BRIDGE_ANGLE)
        bridge_height = Mineshift.perlin.prng_int(layer, rect_index, 
          (Layer::DATA[layer][:block_size]*Bridge::MIN_HEIGHT_RATIO).to_i, 
          (Layer::DATA[layer][:block_size]*Bridge::MAX_HEIGHT_RATIO).to_i, 
          Seeds::BRIDGE_HEIGHT
        )

        # Top point above the center of the bridge
        bridge_center_top_point = Rl::Vector2.new(x: mask_center_point.x, y: (mask_center_point.y - bridge_height/2.0_f32))
        # Bottom point above the center of the bridge
        bridge_center_bottom_point = Rl::Vector2.new(x: mask_center_point.x, y: (mask_center_point.y + bridge_height/2.0_f32))

        bridge_collision_seg_size = Layer::DATA[layer][:block_size] * Bridge::COLLISION_SEGMENT_RATIO

        bridge_ray = Math.rotate_point(bridge_collision_seg_size, 0, 0, 0, bridge_angle)
        left_top_point = bridge_center_top_point

        while left_top_point.x > 0 && left_top_point.x < Mineshift.virtual_screen_width &&
              left_top_point.y > 0 && left_top_point.y < Layer.height(layer) &&
              chasm_rects.any? { |cr| Rl.check_collision_point_rec?(left_top_point, cr) }
          left_top_point = Rl::Vector2.new(
            x: (left_top_point.x - bridge_ray.x),
            y: (left_top_point.y - bridge_ray.y),
          )

          if !chasm_rects.any? { |cr| Rl.check_collision_point_rec?(left_top_point, cr) }
            left_bot_point = Rl::Vector2.new(
              x: left_top_point.x,
              y: (left_top_point.y + bridge_height),
            )

            if !chasm_rects.any? { |cr| Rl.check_collision_point_rec?(left_bot_point, cr) }
              right_top_point = bridge_center_top_point
              while right_top_point.x > 0 && right_top_point.x < Mineshift.virtual_screen_width &&
                    right_top_point.y > 0 && right_top_point.y < (Layer.height(layer)) &&
                    chasm_rects.any? { |cr| Rl.check_collision_point_rec?(right_top_point, cr) }
                right_top_point = Rl::Vector2.new(
                  x: (right_top_point.x + bridge_ray.x),
                  y: (right_top_point.y + bridge_ray.y),
                )
              end
              if !chasm_rects.any? { |cr| Rl.check_collision_point_rec?(right_top_point, cr) }
                right_bot_point = Rl::Vector2.new(
                  x: right_top_point.x,
                  y: (right_top_point.y + bridge_height),
                )

                if !chasm_rects.any? { |cr| Rl.check_collision_point_rec?(right_bot_point, cr) }
                  bb = Rl::Rectangle.new
                  if left_top_point.y < right_top_point.y
                    bb.x = left_top_point.x.to_i
                    bb.y = left_top_point.y.to_i
                    bb.width = (right_top_point.x - left_top_point.x).to_i
                    bb.height = (right_bot_point.y - left_top_point.y).to_i
                  else
                    bb.x = left_top_point.x.to_i
                    bb.y = right_top_point.y.to_i
                    bb.width = (right_top_point.x - left_top_point.x).to_i
                    bb.height = (left_bot_point.y - right_top_point.y).to_i
                  end
                  
                  # Do we have anything to even check collision to?
                  if (bridge_bounding_boxes.empty? || 
                    # Does this bridge collide with another bridge?
                    !bridge_bounding_boxes.any? { |b_bb| Rl.check_collision_recs?(bb, b_bb) }) &&
                    # Is the bridge entirely on the texture?
                    !bridge_bounding_boxes.any? { |b_bb| (b_bb.y + b_bb.height) > Layer.height(layer) || b_bb.y < 0}


                    # Add to the bounding boxes
                    bridge_bounding_boxes << bb

                    # draw the bridge with triangles
                    Rl.draw_triangle(left_top_point, left_bot_point, right_bot_point, Rl::WHITE)
                    Rl.draw_triangle(left_top_point, right_bot_point, right_top_point, Rl::WHITE)
                  end
                end
              end
            end
          end
        end
      end
      bridge_bounding_boxes
    end

  end
end