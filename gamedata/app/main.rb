class Blob
  attr_accessor :slot_x, :slot_y, :color, :controlled
  # the first blob is center blob for rotation
  # spawned groups are always in 2
  # once 4 or more blob connected together, it pops
  # you only have 1 active controllable blob pair at a time
  def initialize args, x, y
    @args = args
    @slot_x = x
    @slot_y = y
    @color = [:red, :green, :blue, :yellow, :purple].sample
    @controlled = true
    @game_state = :init
  end
end

class Puyo
  def initialize args
    @args = args
    @grid_w = 6
    @grid_h = 12
    @blob_sz = 60
    @blobs = []
    @lastUpdated = args.state.tick_count
    @spawning_blobs = false
    @speed = 1
    @score = 0
  end

  def grid_w_total
    @grid_w * @blob_sz
  end

  def grid_h_total
    @grid_h * @blob_sz
  end

  def grid_x
    @args.grid.w / 2 - grid_w_total / 2
  end

  def grid_y
    @args.grid.h / 2 - grid_h_total / 2
  end
  
  def render_grid
    # @banner_sprite_sze ||= @args.gtk.calcspritebox('sprites/marisa.png')
    # w, h = @banner_sprite_sze
    # @args.outputs.primitives << [0, 120, w * 0.5, h * 0.5, 'sprites/marisa.png', 0, [0.2 * 225, 255,255,255]].sprite
    @args.outputs.primitives << [grid_x, grid_y, grid_w_total, grid_h_total, [255, 255, 255]].solid
  end

  def render_blobs
    @blobs.sort_by(&:slot_x).each do |blob|
      x = grid_x + blob.slot_x * @blob_sz
      y = grid_y + blob.slot_y * @blob_sz
      color = case blob.color
      when :red then [255,150,150]
      when :green then [150,255,150]
      when :blue then [150,150,255]
      when :yellow then [255,255,150]
      when :purple then [255,150,255]
      else [0, 0, 0]
      end
      @blob_sprite_size ||= @args.gtk.calcspritebox('sprites/mofu2.png')
      w, h = @blob_sprite_size
      @args.outputs.primitives << [x - (@blob_sz * 0.5 / 2), y, @blob_sz * 1.5, h * (@blob_sz / w) * 1.5, 'sprites/mofu2.png', 0, 255, color].sprite
      # @args.outputs.primitives << [x, y, @blob_sz, @blob_sz, color].solids
      # update to wrap groups by border
      # @args.outputs.borders << [x, y, @blob_sz, @blob_sz]
    end
  end
  
  def render
    render_grid
    render_blobs
    # @args.outputs.primitives << [50, 200, 'puyo', 30, 0, [255, 255, 255]].label
    @args.outputs.primitives << [@args.grid.w - 50, @args.grid.h - 50, "Score: #{@score}", 20 , 2, [255, 255, 255]].label
    if @game_state != :running
      @args.outputs.primitives << [@args.grid.w - 50, @args.grid.h - 120, "- Click Anywhere to Start -", 4 , 2, [255, 255, 255]].label
    end
    # @args.outputs.primitives << [0, 200, "freefall: #{@freefall_in_progress}", 2, 0, [255, 255, 255]].label
    # @args.outputs.primitives << [100, 600, "total: #{blob_groups.map{|bg| "#{bg.first.color}: #{bg.size}"}.join("\n")}", 1, 0, [255, 0, 0]].label
  end

  def controllable_blobs
    @blobs.filter {|b| b.controlled}
  end

  def uncontrollable_blobs
    @blobs.filter {|b| !b.controlled}
  end
  
  def blob_slot_available x, y
    x_valid = x >= 0 && x < @grid_w
    y_valid = y >= 0 && x < @grid_h + 2
    slot_taken = uncontrollable_blobs.any? {|b| b.slot_x == x && b.slot_y == y}
    x_valid && y_valid && !slot_taken
  end

  def rotate_by x, y, center_x, center_y
    new_x, new_y = case [center_x - x, center_y - y]
    when [0, -1] then [-1, 0]
    when [-1, 0] then [0, 1]
    when [0, 1] then [1, 0]
    when [1, 0] then [0, -1]
    end
    [center_x + new_x, center_y + new_y]
  end

  def blob_groups
    blob_groups = []
    uncontrollable_blobs
      .filter {|b| !blob_slot_available(b.slot_x, b.slot_y - 1)}
      .each do |blob|
      if blob_groups.size == 0
        blob_groups << [blob]
      else
        matching_groups = blob_groups
          .filter {|bg| bg.any? {|b| b.color == blob.color}}
          .filter {|bg| bg.any? {|b| ((b.slot_x - blob.slot_x).abs + (b.slot_y - blob.slot_y).abs) == 1}}
        matching_groups.each do |mg|
          blob_groups.delete(mg)
        end
        new_group = matching_groups.flatten
        new_group << blob
        blob_groups << new_group
      end
    end
    blob_groups
  end

  def add_blobpair
    x = rand(@grid_w)
    y = @grid_h + 2 # spawn above game grid
    blob = Blob.new @args, x, y
    blob2 = Blob.new @args, x, y - 1
    @blobs << blob << blob2
  end

  def update
    if @args.inputs.mouse.click && @game_state != :running
      @blobs.clear
      @score = 0
      @game_state = :running
    end
    if @game_state == :running && !controllable_blobs.any? # && @args.inputs.keyboard.e
      @spawning_blobs = true
    end

    ## controls
    if @args.inputs.keyboard.key_down.r
      center_blob, *rest_blobs = controllable_blobs
      if (rest_blobs
        .map{|b| rotate_by(b.slot_x, b.slot_y, center_blob.slot_x, center_blob.slot_y)}
        .all?{|b| blob_slot_available(b[0], b[1])})
        rest_blobs.each do |blob|
          new_x, new_y = rotate_by blob.slot_x, blob.slot_y, center_blob.slot_x, center_blob.slot_y
          blob.slot_x = new_x
          blob.slot_y = new_y
        end
      end
    elsif @args.inputs.keyboard.key_down.a || @args.inputs.keyboard.key_down.d
      x_move = 0
      if @args.inputs.keyboard.key_down.a
        x_move -= 1
      end
      if @args.inputs.keyboard.key_down.d
        x_move += 1
      end
      if controllable_blobs.all? {|b| blob_slot_available b.slot_x + x_move, b.slot_y}
        controllable_blobs.each do |blob|
          blob.slot_x += x_move
        end
      end
    end
    if @args.inputs.keyboard.key_held.space
      @speed = 10
    else
      @speed = 1
    end

    ## auto updates
    blobs_to_delete = blob_groups
      .filter {|bg| bg.size >= 4}
      .flatten
    if !@freefall_in_progress && blobs_to_delete.any?
      blobs_to_delete.each do |blob|
        @score += 10
        @blobs.delete(blob)
      end
      @freefall_in_progress = true
    end
    if @lastUpdated.elapsed_time > 60 * 0.5 / (@speed + (@freefall_in_progress ? 5 : 0) + @lastUpdated.elapsed_time / 20) # 2 seconds
      original_uncontrollable_blobs = uncontrollable_blobs
      if @spawning_blobs && @game_state == :running && !(@blobs.size != 0 && @freefall_in_progress)
        add_blobpair
        @spawning_blobs = false
      end
      ## fall
      @freefall_in_progress = false
      uncontrollable_blobs
        .sort_by(&:slot_y) # fall lower ones first
        .each do |blob|
        if blob_slot_available(blob.slot_x, blob.slot_y - 1)
          @freefall_in_progress = true
          blob.slot_y = blob.slot_y - 1
        end
      end
      if controllable_blobs.all? {|b| blob_slot_available b.slot_x, b.slot_y - 1}
        controllable_blobs.each do |blob|
          blob.slot_y = blob.slot_y - 1
        end
      elsif
        controllable_blobs.each do |blob|
          blob.controlled = false
          @freefall_in_progress = true
        end
      end

      # win lost
      if @game_state == :running && uncontrollable_blobs.any? {|b| b.slot_y >= @grid_h}
        @game_state = :lost
      end
      @lastUpdated = @args.state.tick_count
    end
  end
  
  def tick
    update
    render
  end
end


def tick args
  args.outputs.background_color = [29, 31, 33]
  args.state.game ||= Puyo.new args
  args.state.game.tick
end

$gtk.reset