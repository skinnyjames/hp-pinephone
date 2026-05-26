class Timer
  attr_accessor :start, :done

  def initialize
    @start = Hokusai.monotonic
    @done = Hokusai.monotonic
  end

  def elapsed?(s)
    @done - @start > s
  end

  def reset
    @start = Hokusai.monotonic
    @done = Hokusai.monotonic
  end

  def next
    @done = Hokusai.monotonic
  end
end

class ACamera < Hokusai::Block
  template <<~EOF
  [template]
    empty { @click="shit" }
  EOF

  uses(empty: Hokusai::Blocks::Empty)

  attr_accessor :lw, :lh, :texture, :camera

  def initialize(**args)
    @lw = nil
    @lh = nil
    @texture = nil
    @camera = nil
    @timer = Timer.new
    @filter = false
    super
  end
  
  def shit(event)
    @filter = !@filter
  end

  def render(canvas)
    if @camera.nil?
      self.camera = ::V4L2::Camera.init("/dev/video0", canvas.width.to_i, canvas.height.to_i)
      camera.open

      # Use actual negotiated dimensions, not requested ones
      self.lw = camera.width
      self.lh = camera.height
      self.texture = Hokusai::Texture.init(lw, lh)
      self.texture.clear
    end

    # if @timer.elapsed?(0.033)
      frame = self.camera.frame
      if frame
        self.texture.update(frame) if frame.bytesize == lw * lh * 4
      end
      
      @timer.reset
    # end
    @timer.next

    draw_with do |c|
      if @filter
        c.blend_mode_begin("multiply")
        c.rect(canvas.x, canvas.y, canvas.width, canvas.height) do |com|
          com.color = Hokusai::Color.new(222,22,22)
        end
      end
        c.texture(@texture, canvas.x, canvas.y) do |command|
          command.flip = false
        end
      if @filter
        c.blend_mode_end
      end
    end

    yield canvas
  end
end


class Foo < Hokusai::Block
  template do
    child(ACamera) do
    end

    child(Hokusai::Blocks::Vblock) do
      prop :background do
        Hokusai::Color.new(22, 85, 130)
      end

      static :cursor, "'pointer'"

      child(Hokusai::Blocks::Empty) do
        on :click do |event|
          args = [
            "Yo boy sean :)",
            0,
            "dialog-information",
            "Clicked!",
            "#{event.pos.x}, #{event.pos.y}",
            [],
            {"image-path" => ["s", "/home/skinnyjames/smile.png"]},
            0
          ]
          p "calling notify"
          p notify.meta[:methods]
          p notify.call("Notify", args)
        end
      end
    end
  end

  attr_reader :notify

  def initialize(**args)
    @notify = SDBus.user.service("org.freedesktop.Notifications")
                        .object("/org/freedesktop/Notifications")
                        .interface("org.freedesktop.Notifications")
    @notify.meta

    super
  end
end

class App < Hokusai::Block
  template do
    child(Foo) do
      
    end
  end

  def before_updated
    p "hello"
  end
end

Hokusai::Backend.run(App) do |config|
  config.title = "SDBus Test"
  config.height = 800
  config.width = 500
  config.fps = 60
  config.after_load do
    Hokusai.fonts.register "default", Hokusai::Backend::Font.default
    Hokusai.fonts.activate "default"
  end
end

