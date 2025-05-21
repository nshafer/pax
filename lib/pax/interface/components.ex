defmodule Pax.Interface.Components do
  use Phoenix.Component
  import Pax.Components
  import Pax.Util.String

  attr :pax, Pax.Interface.Context, required: true
  attr :class, :string, default: nil
  attr :index_class, :string, default: nil
  attr :show_class, :string, default: nil
  attr :new_class, :string, default: nil
  attr :edit_class, :string, default: nil

  def pax_interface(assigns) do
    ~H"""
    <div :if={assigns[:pax]} class="pax-interface">
      {pax_interface_action(assigns)}
    </div>
    """
  end

  def pax_interface_action(assigns) do
    case assigns.pax.action do
      :index -> assigns |> Map.put(:class, assigns.index_class) |> pax_index()
      :show -> assigns |> Map.put(:class, assigns.show_class) |> pax_show()
      :new -> assigns |> Map.put(:class, assigns.new_class) |> pax_new()
      :edit -> assigns |> Map.put(:class, assigns.edit_class) |> pax_edit()
      _ -> nil
    end
  end

  attr :pax, Pax.Interface.Context, required: true
  attr :class, :string, default: nil

  def pax_index(assigns) do
    ~H"""
    <div class={["pax-index", @class]}>
      <.pax_header class="pax-index-header">
        <:primary>
          {Pax.Plugin.render(:index_header_primary, assigns)}
        </:primary>

        <:secondary>
          {Pax.Plugin.render(:index_header_secondary, assigns)}
          <.pax_button :if={@pax.new_path} navigate={@pax.new_path} level={:primary}>
            New {truncate(@pax.singular_name, 25)}
          </.pax_button>
        </:secondary>

        <:tertiary>
          {Pax.Plugin.render(:index_header_tertiary, assigns)}
        </:tertiary>
      </.pax_header>

      <div class="pax-index-body">
        {Pax.Plugin.render(:index_body, assigns)}
      </div>

      <.pax_footer class="pax-index-footer">
        <:primary>
          {Pax.Plugin.render(:index_footer_primary, assigns)}
        </:primary>

        <:secondary>
          {Pax.Plugin.render(:index_footer_secondary, assigns)}
        </:secondary>

        <:tertiary>
          {Pax.Plugin.render(:index_footer_tertiary, assigns)}
        </:tertiary>
      </.pax_footer>
    </div>
    """
  end

  attr :pax, Pax.Interface.Context, required: true
  attr :class, :string, default: nil

  def pax_show(assigns) do
    ~H"""
    <div class={["pax-detail pax-detail-show", @class]}>
      <.pax_header class="pax-detail-header pax-detail-show-header">
        <:primary>
          {Pax.Plugin.render(:show_header_primary, assigns)}
        </:primary>

        <:secondary>
          {Pax.Plugin.render(:show_header_secondary, assigns)}
          <.pax_button :if={@pax.edit_path} class="pax-detail-edit-button" patch={@pax.edit_path} level={:primary}>
            Edit
          </.pax_button>
        </:secondary>

        <:tertiary>
          {Pax.Plugin.render(:show_header_tertiary, assigns)}
        </:tertiary>
      </.pax_header>

      <div class="pax-detail-body">
        {Pax.Plugin.render(:show_body, assigns)}
      </div>

      <.pax_footer class="pax-detail-footer pax-detail-show-footer">
        <:primary>
          {Pax.Plugin.render(:show_footer_primary, assigns)}
        </:primary>

        <:secondary>
          {Pax.Plugin.render(:show_footer_secondary, assigns)}
        </:secondary>

        <:tertiary>
          {Pax.Plugin.render(:show_footer_tertiary, assigns)}
        </:tertiary>
      </.pax_footer>
    </div>
    """
  end

  attr :pax, Pax.Interface.Context, required: true
  attr :class, :string, default: nil

  def pax_edit(assigns) do
    ~H"""
    <.form for={@pax.form} class={["pax-detail pax-detail-edit", @class]} phx-change="pax_validate" phx-submit="pax_save">
      <.pax_header class="pax-detail-header pax-detail-edit-header">
        <:primary>
          {Pax.Plugin.render(:edit_header_primary, assigns)}
        </:primary>

        <:secondary>
          {Pax.Plugin.render(:edit_header_secondary, assigns)}
          <.pax_button :if={@pax.show_path} class="pax-detail-cancel-button" patch={@pax.show_path} level={:secondary}>
            Cancel
          </.pax_button>

          <.pax_button
            class="pax-detail-save-button"
            type="submit"
            phx-disable-with="Saving..."
            name="detail[save]"
            value="save"
            level={:primary}
          >
            Save
          </.pax_button>
        </:secondary>
        <:tertiary>
          {Pax.Plugin.render(:edit_header_tertiary, assigns)}
        </:tertiary>
      </.pax_header>

      <div class="pax-detail-body">
        {Pax.Plugin.render(:edit_body, assigns)}
      </div>

      <.pax_footer class="pax-detail-footer pax-detail-edit-footer">
        <:primary>
          {Pax.Plugin.render(:edit_footer_primary, assigns)}
        </:primary>

        <:secondary>
          {Pax.Plugin.render(:edit_footer_secondary, assigns)}
        </:secondary>

        <:tertiary>
          {Pax.Plugin.render(:edit_footer_tertiary, assigns)}
        </:tertiary>
      </.pax_footer>
    </.form>
    """
  end

  attr :pax, Pax.Interface.Context, required: true
  attr :class, :string, default: nil

  def pax_new(assigns) do
    ~H"""
    <.form for={@pax.form} class={["pax-detail pax-detail-new", @class]} phx-change="pax_validate" phx-submit="pax_save">
      <.pax_header class="pax-detail-header pax-detail-new-header">
        <:primary>
          {Pax.Plugin.render(:new_header_primary, assigns)}
        </:primary>

        <:secondary>
          {Pax.Plugin.render(:new_header_secondary, assigns)}
          <.pax_button :if={@pax.index_path} class="pax-detail-cancel-button" patch={@pax.index_path} level={:secondary}>
            Cancel
          </.pax_button>

          <.pax_button
            class="pax-detail-save-button"
            type="submit"
            phx-disable-with="Saving..."
            name="detail[save]"
            value="save"
            level={:primary}
          >
            Save
          </.pax_button>
        </:secondary>
        <:tertiary>
          {Pax.Plugin.render(:new_header_tertiary, assigns)}
        </:tertiary>
      </.pax_header>

      <div class="pax-detail-body">
        {Pax.Plugin.render(:new_body, assigns)}
      </div>

      <.pax_footer class="pax-detail-footer pax-detail-new-footer">
        <:primary>
          {Pax.Plugin.render(:new_footer_primary, assigns)}
        </:primary>

        <:secondary>
          {Pax.Plugin.render(:new_footer_secondary, assigns)}
        </:secondary>

        <:tertiary>
          {Pax.Plugin.render(:new_footer_tertiary, assigns)}
        </:tertiary>
      </.pax_footer>
    </.form>
    """
  end
end
