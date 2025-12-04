defmodule GoGameWeb.PageHTML do
  use GoGameWeb, :html
  # <--- ADD THIS LINE here too
  use Phoenix.Component

  embed_templates "page_html/*"
end
