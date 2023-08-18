defmodule Pax.Admin.ResourceNotFoundError do
  defexception plug_status: 404, message: "resource not found", section: nil, resource: nil

  @impl true
  def exception(opts) do
    section = Keyword.get(opts, :section)
    resource = Keyword.get(opts, :resource)

    if section do
      %Pax.Admin.ResourceNotFoundError{
        message: "resource #{resource} not found in section #{section}",
        section: section,
        resource: resource
      }
    else
      %Pax.Admin.ResourceNotFoundError{
        message: "resource #{resource} not found",
        resource: resource
      }
    end
  end
end
