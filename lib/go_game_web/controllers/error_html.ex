defmodule GoGameWeb.ErrorHTML do
  use GoGameWeb, :html
  use Phoenix.Component

  # If you want to customize error pages, uncomment the line below
  # and create the "lib/go_game_web/controllers/error_html/" directory.
  # embed_templates "error_html/*"

  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
