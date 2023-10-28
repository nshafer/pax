defmodule Pax.Field.Components do
  use Phoenix.Component
  import Pax.Components

  attr :field, :any, required: true
  attr :form, :any, default: nil
  attr :label, :string, default: nil
  attr :for, :string, default: nil
  attr :class, :any, default: nil

  def pax_field_label(assigns) do
    ~H"""
    <label for={@for || Pax.Field.label_for(@field, @form)} class={["pax-field-label", @class]}>
      <%= @label || Pax.Field.label(@field) %>
    </label>
    """
  end

  attr :field, :any, required: true
  attr :object, :map, required: true
  attr :link_class, :string, default: nil
  attr :text_class, :string, default: nil

  def pax_field_link_or_text(assigns) do
    case Pax.Field.link(assigns.field, assigns.object) do
      nil -> pax_field_text(assign(assigns, :class, assigns.text_class))
      link -> pax_field_link(assign(assigns, class: assigns.link_class, link: link))
    end
  end

  attr :field, :any, required: true
  attr :object, :map, required: true
  attr :class, :any, default: nil

  def pax_field_text(assigns) do
    ~H"""
    <div class={["pax-field-text", @class]}>
      <%= Pax.Field.render(@field, @object) %>
    </div>
    """
  end

  attr :field, :any, required: true
  attr :object, :map, required: true
  attr :link, :string, required: true
  attr :class, :any, default: nil

  def pax_field_link(assigns) do
    ~H"""
    <.pax_link class={["pax-field-link", @class]} navigate={@link}>
      <%= Pax.Field.render(@field, @object) %>
    </.pax_link>
    """
  end

  attr :field, :any, required: true
  attr :form, :any, default: nil
  attr :object, :any, required: true
  attr :class, :any, default: nil
  attr :text_class, :any, default: nil
  attr :errors_class, :any, default: nil
  attr :error_class, :any, default: nil

  def pax_field_input(assigns) do
    ~H"""
    <%= if @form == nil or Pax.Field.immutable?(@field) do %>
      <.pax_field_text class={@text_class} field={@field} object={@object} />
    <% else %>
      <div class={["pax-field-input", @class]} phx-feedback-for={Pax.Field.feedback_for(@field, @form)}>
        <%= Pax.Field.input(@field, @form) %>
        <.pax_field_errors field={@field} form={@form} class={@errors_class} error_class={@error_class} />
      </div>
    <% end %>
    """
  end

  attr :field, :any, required: true
  attr :form, :any, default: nil
  attr :class, :any, default: nil
  attr :error_class, :string, default: nil

  def pax_field_errors(assigns) do
    ~H"""
    <div class={["pax-field-errors", @class]}>
      <.pax_field_error :for={msg <- Pax.Field.errors(@field, @form)} class={@error_class}>
        <%= msg %>
      </.pax_field_error>
    </div>
    """
  end

  slot :inner_block, required: true
  attr :class, :any, default: nil

  def pax_field_error(assigns) do
    # TODO: add icon?
    ~H"""
    <div class={["pax-field-error", @class]}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Renders an input control for the given field and form_field. This is for use by Pax.Field implementations.
  As such, it requires a field and form_field, and will render the appropriate input control for the field type.

  The form_field is used to retrieve the input name, id and values, however they can be overriden by
  passing them explicitly.

  ## Types

  This function accepts all HTML input types, considering that:
    * You may also set `type="select"` to render a `<select>` tag
    * `type="checkbox"` is used exclusively to render boolean values
    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :field, :any, required: true
  attr :form_field, Phoenix.HTML.FormField

  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :has_errors, :boolean, default: false

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
               range radio search select tel text textarea time url week)

  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :true_value, :string, default: "True", doc: "the value to display for true checkboxes"
  attr :false_value, :string, default: "False", doc: "the value to display for false checkboxes"

  attr :rest, :global, include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def pax_field_control(%{form_field: %Phoenix.HTML.FormField{} = form_field} = assigns) do
    assigns
    |> assign(:form_field, nil)
    |> assign(:id, assigns.id || form_field.id)
    |> assign(:has_errors, form_field.errors != [])
    |> assign_new(:name, fn -> if assigns.multiple, do: form_field.name <> "[]", else: form_field.name end)
    |> assign_new(:value, fn -> form_field.value end)
    |> pax_field_control()
  end

  def pax_field_control(%{type: "checkbox", value: value} = assigns) do
    # TODO: Perhaps change this to a slider toggle?
    # TODO: Test error condition, such as when the field is required
    assigns = assign_new(assigns, :checked, fn -> Phoenix.HTML.Form.normalize_value("checkbox", value) end)

    ~H"""
    <label class={["pax-field-control-checkbox-label", @has_errors && "has-errors"]}>
      <input type="hidden" name={@name} value="false" />
      <input
        type="checkbox"
        id={@id}
        name={@name}
        class="pax-field-control-checkbox"
        value="true"
        checked={@checked}
        {@rest}
      />
      <span class="pax-field-control-checkbox-true">
        <%= @true_value %>
      </span>
      <span class="pax-field-control-checkbox-false">
        <%= @false_value %>
      </span>
    </label>
    """
  end

  # def field_control(%{type: "select"} = assigns) do
  #   ~H"""
  #   <select
  #     id={@id}
  #     name={@name}
  #     class="mt-2 block w-full rounded-md border border-gray-300 bg-white shadow-sm focus:border-zinc-400 focus:ring-0 sm:text-sm"
  #     multiple={@multiple}
  #     {@rest}
  #   >
  #     <option :if={@prompt} value=""><%= @prompt %></option>
  #     <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
  #   </select>
  #   """
  # end

  # def field_control(%{type: "textarea"} = assigns) do
  #   ~H"""
  #   <textarea
  #     id={@id}
  #     name={@name}
  #     class={[
  #       "mt-2 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
  #       "min-h-[6rem] phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400",
  #       @errors == [] && "border-zinc-300 focus:border-zinc-400",
  #       @errors != [] && "border-rose-400 focus:border-rose-400"
  #     ]}
  #     {@rest}
  #   ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
  #   """
  # end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def pax_field_control(assigns) do
    ~H"""
    <input
      type={@type}
      name={@name || @field.name}
      id={@id}
      value={Phoenix.HTML.Form.normalize_value(@type, @value)}
      class={["pax-field-control-input", @has_errors && "has-errors"]}
      phx-feedback-for={@name || @field.name}
      {@rest}
    />
    """
  end
end
