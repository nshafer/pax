defmodule Pax.Plugins.ActionButtons do
  use Pax.Interface.Plugin
  use Phoenix.Component
  import Pax.Components
  import Pax.Util.String

  @default_new_button_placement :index_header_secondary
  @default_edit_button_placement :show_header_secondary
  @default_edit_cancel_button_placement [:edit_header_secondary, :new_header_secondary]
  @default_edit_save_button_placement [:edit_header_secondary, :new_header_secondary]
  @default_truncate_length 25

  @impl true
  def init(_callback_module, opts) do
    %{
      new_button_placement: Keyword.get(opts, :new_button_placement, @default_new_button_placement),
      edit_button_placement: Keyword.get(opts, :edit_button_placement, @default_edit_button_placement),
      edit_cancel_button_placement:
        Keyword.get(opts, :edit_cancel_button_placement, @default_edit_cancel_button_placement),
      edit_save_button_placement: Keyword.get(opts, :edit_save_button_placement, @default_edit_save_button_placement),
      truncate_length: Keyword.get(opts, :truncate_length, @default_truncate_length)
    }
  end

  @impl true
  def config_key(), do: :action_buttons

  @impl true
  def config_spec() do
    %{
      new_button_placement: [:atom, :list, {:function, 1, [:atom, :list]}],
      edit_button_placement: [:atom, :list, {:function, 1, [:atom, :list]}],
      edit_cancel_button_placement: [:atom, :list, {:function, 1, [:atom, :list]}],
      edit_save_button_placement: [:atom, :list, {:function, 1, [:atom, :list]}],
      truncate_length: [:integer, {:function, 1, :integer}]
    }
  end

  @impl true
  def merge_config(opts, config, socket) do
    %{
      new_button_placement: Pax.Config.get(config, :new_button_placement, [socket], opts.new_button_placement),
      edit_button_placement: Pax.Config.get(config, :edit_button_placement, [socket], opts.edit_button_placement),
      edit_cancel_button_placement:
        Pax.Config.get(config, :edit_cancel_button_placement, [socket], opts.edit_cancel_button_placement),
      edit_save_button_placement:
        Pax.Config.get(config, :edit_save_button_placement, [socket], opts.edit_save_button_placement),
      truncate_length: Pax.Config.get(config, :truncate_length, [socket], opts.truncate_length)
    }
  end

  @impl true
  def render(opts, section, assigns) do
    assigns =
      assigns
      |> assign(:section, section)
      |> assign(:new_button_placement, opts.new_button_placement)
      |> assign(:edit_button_placement, opts.edit_button_placement)
      |> assign(:edit_cancel_button_placement, opts.edit_cancel_button_placement)
      |> assign(:edit_save_button_placement, opts.edit_save_button_placement)
      |> assign(:truncate_length, opts.truncate_length)
      |> assign_cancel_link()

    ~H"""
    {new_button(assigns)}
    {edit_button(assigns)}
    {edit_cancel_button(assigns)}
    {edit_save_button(assigns)}
    """
  end

  defp assign_cancel_link(assigns) do
    cond do
      assigns.pax.show_path -> assign(assigns, :cancel_link, assigns.pax.show_path)
      assigns.pax.index_path -> assign(assigns, :cancel_link, assigns.pax.index_path)
      true -> assign(assigns, :cancel_link, nil)
    end
  end

  # New button

  defp new_button(%{section: section, new_button_placement: section} = assigns) do
    ~H"""
    <.pax_button :if={@pax.new_path} class="pax-action-new-button" patch={@pax.new_path} level={:primary}>
      New {truncate(@pax.singular_name, @truncate_length)}
    </.pax_button>
    """
  end

  defp new_button(%{new_button_placement: placement} = assigns) when is_list(placement) do
    if assigns.pax.new_path && Enum.member?(placement, assigns.section) do
      new_button(assign(assigns, :new_button_placement, assigns.section))
    end
  end

  defp new_button(_assigns), do: nil

  # Edit button

  defp edit_button(%{section: section, edit_button_placement: section} = assigns) do
    ~H"""
    <.pax_button :if={@pax.edit_path} class="pax-action-edit-button" patch={@pax.edit_path} level={:primary}>
      Edit
    </.pax_button>
    """
  end

  defp edit_button(%{edit_button_placement: placement} = assigns) when is_list(placement) do
    if assigns.pax.edit_path && Enum.member?(placement, assigns.section) do
      edit_button(assign(assigns, :edit_button_placement, assigns.section))
    end
  end

  defp edit_button(_assigns), do: nil

  # Edit cancel button

  defp edit_cancel_button(%{section: section, edit_cancel_button_placement: section} = assigns) do
    ~H"""
    <.pax_button :if={@cancel_link} class="pax-action-edit-cancel-button" patch={@cancel_link} level={:secondary}>
      Cancel
    </.pax_button>
    """
  end

  defp edit_cancel_button(%{edit_cancel_button_placement: placement} = assigns) when is_list(placement) do
    if assigns.cancel_link && Enum.member?(placement, assigns.section) do
      edit_cancel_button(assign(assigns, :edit_cancel_button_placement, assigns.section))
    end
  end

  defp edit_cancel_button(_assigns), do: nil

  # Edit save button
  defp edit_save_button(%{section: section, edit_save_button_placement: section} = assigns) do
    ~H"""
    <.pax_button
      :if={@pax.form}
      class="pax-action-edit-save-button"
      type="submit"
      phx-disable-with="Saving..."
      name="detail[save]"
      value="save"
      level={:primary}
    >
      Save
    </.pax_button>
    """
  end

  defp edit_save_button(%{edit_save_button_placement: placement} = assigns) when is_list(placement) do
    if Enum.member?(placement, assigns.section) do
      edit_save_button(assign(assigns, :edit_save_button_placement, assigns.section))
    end
  end

  defp edit_save_button(_assigns), do: nil
end
