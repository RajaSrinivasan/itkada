#include "itklib_internal.hpp"

#include "itkProcessObject.h"
#include "itkVersion.h"

static_assert (ITK_VERSION_MAJOR == 5,
               "this itklib shim is written for ITK 5");

extern "C" const char *
itklib_itk_version (void)
{
  return itk::Version::GetITKVersion ();
}

extern "C" int
itklib_supported (itklib_pixel_id pixel, unsigned dimension)
{
  return itklib_pixel_dim_built (pixel, dimension) ? 1 : 0;
}

extern "C" void
itklib_register (itklib_object * object)
{
  if (object == nullptr || object->obj == nullptr)
    {
      return;
    }
  try
    {
      object->refs.fetch_add (1, std::memory_order_relaxed);
      object->obj->Register ();
      if (object->anchor != nullptr)
        {
          object->anchor->Register ();
        }
    }
  catch (...)
    {
      /* Register is an integer increment. Swallowing keeps the
         exception on the C++ side of the ABI. */
    }
}

extern "C" void
itklib_unregister (itklib_object * object)
{
  if (object == nullptr)
    {
      return;
    }
  try
    {
      const int previous = object->refs.fetch_sub (1, std::memory_order_acq_rel);
      itk::LightObject * raw = object->obj;
      itk::LightObject * anchor = object->anchor;
      if (anchor != nullptr)
        {
          anchor->UnRegister ();
        }
      if (previous == 1)
        {
          object->obj = nullptr;
          object->anchor = nullptr;
          if (raw != nullptr)
            {
              raw->UnRegister ();
            }
          itklib_live_wrappers ().fetch_sub (1, std::memory_order_relaxed);
          delete object;
        }
      else if (raw != nullptr)
        {
          raw->UnRegister ();
        }
    }
  catch (...)
    {
    }
}

extern "C" int
itklib_reference_count (itklib_object * object)
{
  if (object == nullptr || object->obj == nullptr)
    {
      return 0;
    }
  return object->obj->GetReferenceCount ();
}

extern "C" int
itklib_debug_live_objects (void)
{
  return itklib_live_objects ().load (std::memory_order_relaxed);
}

extern "C" int
itklib_debug_live_wrappers (void)
{
  return itklib_live_wrappers ().load (std::memory_order_relaxed);
}

extern "C" int
itklib_update (itklib_object * process, itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (process == nullptr || process->obj == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null process object", "itklib_update"};
      }
    auto * filter = dynamic_cast<itk::ProcessObject *> (process->obj);
    if (filter == nullptr)
      {
        throw itklib_status{ITKLIB_E_ARG, "object is not an ITK process object",
                            "itklib_update"};
      }
    itklib_reject_locked_outputs (filter);
    filter->Update ();
  });
}

extern "C" int
itklib_modified (itklib_object * process, itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (process == nullptr || process->obj == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null process object",
                            "itklib_modified"};
      }
    auto * object = dynamic_cast<itk::Object *> (process->obj);
    if (object == nullptr)
      {
        throw itklib_status{ITKLIB_E_ARG, "object cannot be marked modified",
                            "itklib_modified"};
      }
    object->Modified ();
  });
}

extern "C" int
itklib_update_largest_possible_region (itklib_object * process,
                                       itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (process == nullptr || process->obj == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null process object",
                            "itklib_update_largest_possible_region"};
      }
    auto * filter = dynamic_cast<itk::ProcessObject *> (process->obj);
    if (filter == nullptr)
      {
        throw itklib_status{ITKLIB_E_ARG, "object is not an ITK process object",
                            "itklib_update_largest_possible_region"};
      }
    itklib_reject_locked_outputs (filter);
    filter->UpdateLargestPossibleRegion ();
  });
}

extern "C" int
itklib_set_number_of_work_units (itklib_object * process, unsigned count,
                                 itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (process == nullptr || process->obj == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null process object",
                            "itklib_set_number_of_work_units"};
      }
    if (count == 0)
      {
        throw itklib_status{ITKLIB_E_ARG, "work unit count must be positive",
                            "itklib_set_number_of_work_units"};
      }
    auto * filter = dynamic_cast<itk::ProcessObject *> (process->obj);
    if (filter == nullptr)
      {
        throw itklib_status{ITKLIB_E_ARG, "object is not an ITK process object",
                            "itklib_set_number_of_work_units"};
      }
    filter->SetNumberOfWorkUnits (count);
  });
}
