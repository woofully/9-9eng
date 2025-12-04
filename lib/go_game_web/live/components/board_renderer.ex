defmodule GoGameWeb.Components.BoardRenderer do
  use Phoenix.Component

  # Constants for drawing math
  @cell_size 80
  @padding 60
  @board_size 9
  # SVG Viewbox width = (8 spaces * 80px) + (2 * 60px padding) = 640 + 120 = 760
  @viewbox_size (@board_size - 1) * @cell_size + @padding * 2

  attr :board, :map, required: true, doc: "The board state map %{{x,y} => :black | :white}"
  attr :interactive, :boolean, default: true, doc: "Whether clicks are enabled"

  def board(assigns) do
    assigns =
      assigns
      |> assign(:viewbox_size, @viewbox_size)
      |> assign(:board_size, @board_size)
      |> assign(:cell_size, @cell_size)
      |> assign(:padding, @padding)

    ~H"""
    <div class="block rounded-lg shadow-2xl overflow-hidden bg-[#dcb35c]">
      <svg
        viewBox={"0 0 #{@viewbox_size} #{@viewbox_size}"}
        width="100%"
        height="100%"
        class="block cursor-pointer touch-manipulation select-none"
      >
        <defs>
          <!-- 3D Gradients for Stones -->
          <radialGradient id="grad-black" cx="30%" cy="30%" r="70%">
            <stop offset="0%" stop-color="#666" />
            <!-- Glint -->
            <stop offset="20%" stop-color="#333" />
            <stop offset="100%" stop-color="#000" />
          </radialGradient>

          <radialGradient id="grad-white" cx="35%" cy="35%" r="65%">
            <stop offset="0%" stop-color="#fff" />
            <stop offset="100%" stop-color="#d1d1d1" />
            <!-- Shadowy edge -->
          </radialGradient>
          
    <!-- Drop Shadow Filter for Stones -->
          <filter id="stone-shadow" x="-50%" y="-50%" width="200%" height="200%">
            <feDropShadow dx="2" dy="4" stdDeviation="2" flood-color="#000" flood-opacity="0.3" />
          </filter>
        </defs>
        
    <!-- 1. The Wood Background Texture (simulated with noise or just color) -->
        <rect x="0" y="0" width={@viewbox_size} height={@viewbox_size} fill="#dcb35c" />
        
    <!-- 2. Grid Lines -->
        <g stroke="#5e4b35" stroke-width="3" stroke-linecap="square">
          <!-- Horizontal Lines -->
          <%= for i <- 0..(@board_size - 1) do %>
            <line
              x1={@padding}
              y1={@padding + i * @cell_size}
              x2={@viewbox_size - @padding}
              y2={@padding + i * @cell_size}
            />
          <% end %>
          
    <!-- Vertical Lines -->
          <%= for i <- 0..(@board_size - 1) do %>
            <line
              x1={@padding + i * @cell_size}
              y1={@padding}
              x2={@padding + i * @cell_size}
              y2={@viewbox_size - @padding}
            />
          <% end %>
        </g>
        
    <!-- 3. Star Points (Hoshi) for 9x9: (2,2), (6,2), (4,4), (2,6), (6,6) -->
        <%= for {sx, sy} <- [{2,2}, {6,2}, {4,4}, {2,6}, {6,6}] do %>
          <circle
            cx={@padding + sx * @cell_size}
            cy={@padding + sy * @cell_size}
            r="6"
            fill="#5e4b35"
          />
        <% end %>
        
    <!-- 4. Click Targets (Invisible Hit Areas) -->
        <!-- We render these UNDER the stones but OVER the lines so clicks work even if empty -->
        <%= if @interactive do %>
          <%= for x <- 0..(@board_size - 1), y <- 0..(@board_size - 1) do %>
            <rect
              x={@padding + x * @cell_size - @cell_size / 2}
              y={@padding + y * @cell_size - @cell_size / 2}
              width={@cell_size}
              height={@cell_size}
              fill="transparent"
              phx-click="make_move"
              phx-value-x={x}
              phx-value-y={y}
              class="hover:opacity-10"
            />
          <% end %>
        <% end %>
        
    <!-- 5. Stones -->
        <%= for {{x, y}, color} <- @board do %>
          <circle
            cx={@padding + x * @cell_size}
            cy={@padding + y * @cell_size}
            r={@cell_size / 2.2}
            fill={if color == :black, do: "url(#grad-black)", else: "url(#grad-white)"}
            filter="url(#stone-shadow)"
            class="pointer-events-none"
          />
        <% end %>
      </svg>
    </div>
    """
  end
end
