#pragma once

#include "itklib.h"

#include "itkConfigure.h"
#include "itkDataObject.h"
#include "itkEventObject.h"
#include "itkLightObject.h"
#include "itkMacro.h"
#include "itkObject.h"
#include "itkProcessObject.h"
#include "itkSmartPointer.h"

#include <atomic>
#include <cstdint>
#include <cstring>
#include <mutex>
#include <new>
#include <string>
#include <unordered_map>
#include <utility>
#include <vector>

enum {
  ITKLIB_CLASS_IMAGE = 1,
  ITKLIB_CLASS_READER = 2,
  ITKLIB_CLASS_WRITER = 3,
  ITKLIB_CLASS_GAUSSIAN = 4,
  ITKLIB_CLASS_MEDIAN = 5,
  ITKLIB_CLASS_THRESHOLD = 6,
  ITKLIB_CLASS_RESCALE = 7,
  ITKLIB_CLASS_SHRINK = 8,
  ITKLIB_CLASS_RESAMPLE = 9,
  ITKLIB_CLASS_FLIP = 10,
  ITKLIB_CLASS_EXTRACT = 11,
  ITKLIB_CLASS_GRADIENT = 12,
  ITKLIB_CLASS_STATISTICS = 13
};

struct itklib_object {
  itk::LightObject * obj;
  itk::LightObject * anchor;
  itklib_pixel_id pixel;
  unsigned dim;
  int klass;
  std::atomic<int> refs;
};

struct itklib_status {
  int code;
  const char * what;
  const char * where;
};

inline std::atomic<int> &
itklib_live_objects ()
{
  static std::atomic<int> count{0};
  return count;
}

inline std::atomic<int> &
itklib_live_wrappers ()
{
  static std::atomic<int> count{0};
  return count;
}

inline bool
itklib_pixel_dim_built (itklib_pixel_id pixel, unsigned dimension)
{
  return pixel == ITKLIB_UINT16 && (dimension == 2 || dimension == 3);
}

inline void
itklib_copy_text (char * destination, size_t capacity, const char * source)
{
  if (capacity == 0)
    {
      return;
    }
  if (source == nullptr)
    {
      destination[0] = '\0';
      return;
    }
  std::strncpy (destination, source, capacity - 1);
  destination[capacity - 1] = '\0';
}

inline int
itklib_fail (itklib_error * error, int code, const char * what,
             const char * where)
{
  if (error != nullptr)
    {
      error->code = code;
      itklib_copy_text (error->what, sizeof error->what, what);
      itklib_copy_text (error->where, sizeof error->where, where);
    }
  return code;
}

inline int
itklib_fail_itk (itklib_error * error, const itk::ExceptionObject & exception)
{
  /* what() stays valid for the life of the exception object. Copy it
     before the catch clause ends. */
  const char * text = exception.what ();
  std::string where;
  if (exception.GetFile () != nullptr)
    {
      where = exception.GetFile ();
      where += ":";
      where += std::to_string (exception.GetLine ());
    }
  return itklib_fail (error, ITKLIB_E_ITK,
                      text != nullptr && text[0] != '\0' ? text : "ITK exception",
                      where.c_str ());
}

template <typename Action>
int
itklib_guard (itklib_error * error, Action && action)
{
  try
    {
      if (error != nullptr)
        {
          error->code = ITKLIB_OK;
          error->what[0] = '\0';
          error->where[0] = '\0';
        }
      std::forward<Action> (action) ();
      return ITKLIB_OK;
    }
  catch (const itk::ExceptionObject & exception)
    {
      return itklib_fail_itk (error, exception);
    }
  catch (const itklib_status & status)
    {
      return itklib_fail (error, status.code, status.what, status.where);
    }
  catch (const std::bad_alloc & exception)
    {
      return itklib_fail (error, ITKLIB_E_BAD_ALLOC, exception.what (),
                          "std::bad_alloc");
    }
  catch (const std::exception & exception)
    {
      return itklib_fail (error, ITKLIB_E_STD, exception.what (),
                          "std::exception");
    }
  catch (...)
    {
      return itklib_fail (error, ITKLIB_E_UNKNOWN, "unknown C++ exception",
                          "");
    }
}

inline void
itklib_arm (itk::Object * object)
{
  itklib_live_objects ().fetch_add (1, std::memory_order_relaxed);
  object->AddObserver (itk::DeleteEvent (), [] (const itk::EventObject &) {
    itklib_live_objects ().fetch_sub (1, std::memory_order_relaxed);
  });
}

/* The returned wrapper owns exactly one ITK reference, taken here.
   The caller's smart pointer must still be alive and is expected to
   drop its own reference when it goes out of scope. */
inline itklib_object *
itklib_adopt (itk::LightObject * raw, itklib_pixel_id pixel, unsigned dimension,
              int klass, bool arm_object)
{
  if (raw == nullptr)
    {
      throw itklib_status{ITKLIB_E_NULL, "ITK object pointer is null", ""};
    }
  raw->Register ();
  itklib_object * wrap = new itklib_object;
  wrap->obj = raw;
  wrap->anchor = nullptr;
  wrap->pixel = pixel;
  wrap->dim = dimension;
  wrap->klass = klass;
  wrap->refs.store (1, std::memory_order_relaxed);
  itklib_live_wrappers ().fetch_add (1, std::memory_order_relaxed);
  if (arm_object)
    {
      if (auto * object = dynamic_cast<itk::Object *> (raw))
        {
          itklib_arm (object);
        }
    }
  return wrap;
}

inline void
itklib_require_built (itklib_pixel_id pixel, unsigned dimension)
{
  if (!itklib_pixel_dim_built (pixel, dimension))
    {
      throw itklib_status{ITKLIB_E_UNSUPPORTED,
                          "pixel/dimension is not built in this itklib",
                          "itklib_require_built"};
    }
}

/* The output image's ITK source is a weak pointer, so dropping the Ada
   filter would destroy the producer. Each Get_Output wrapper holds one
   strong reference per wrapper ref (anchor). Set_Input also retains the
   input's source for as long as the consumer process object lives. */

inline std::recursive_mutex &
itklib_upstream_mutex ()
{
  static std::recursive_mutex mutex;
  return mutex;
}

struct itklib_upstream
{
  std::vector<itk::SmartPointer<itk::LightObject>> held;
  bool watching = false;
};

inline std::unordered_map<itk::Object *, itklib_upstream> &
itklib_upstreams ()
{
  static std::unordered_map<itk::Object *, itklib_upstream> table;
  return table;
}

inline void
itklib_retain_source (itk::ProcessObject * consumer, itk::DataObject * input)
{
  if (consumer == nullptr || input == nullptr)
    {
      return;
    }
  itk::ProcessObject * source = input->GetSource ();
  if (source == nullptr || source == consumer)
    {
      return;
    }
  std::lock_guard<std::recursive_mutex> guard (itklib_upstream_mutex ());
  itklib_upstream & slot = itklib_upstreams ()[consumer];
  if (!slot.watching)
    {
      consumer->AddObserver (itk::DeleteEvent (),
                             [consumer] (const itk::EventObject &) {
                               std::lock_guard<std::recursive_mutex> inner (
                                 itklib_upstream_mutex ());
                               itklib_upstreams ().erase (consumer);
                             });
      slot.watching = true;
    }
  std::vector<itk::SmartPointer<itk::LightObject>> next;
  next.push_back (source);
  itklib_upstreams ()[consumer].held.swap (next);
}

inline std::mutex &
itklib_buffer_mutex ()
{
  static std::mutex mutex;
  return mutex;
}

inline std::unordered_map<itk::LightObject *, int> &
itklib_buffer_locks ()
{
  static std::unordered_map<itk::LightObject *, int> table;
  return table;
}

inline void
itklib_buffer_lock_add (itk::LightObject * object, int delta)
{
  if (object == nullptr)
    {
      return;
    }
  std::lock_guard<std::mutex> guard (itklib_buffer_mutex ());
  int & slot = itklib_buffer_locks ()[object];
  slot += delta;
  if (slot <= 0)
    {
      itklib_buffer_locks ().erase (object);
    }
}

inline bool
itklib_buffer_is_locked (const itk::LightObject * object)
{
  if (object == nullptr)
    {
      return false;
    }
  std::lock_guard<std::mutex> guard (itklib_buffer_mutex ());
  const auto found = itklib_buffer_locks ().find (
    const_cast<itk::LightObject *> (object));
  return found != itklib_buffer_locks ().end () && found->second > 0;
}

inline void
itklib_reject_locked_outputs (itk::ProcessObject * filter)
{
  if (filter == nullptr)
    {
      return;
    }
  const auto outputs = filter->GetOutputs ();
  for (const auto & output : outputs)
    {
      if (itklib_buffer_is_locked (output.GetPointer ()))
        {
          throw itklib_status{
            ITKLIB_E_ARG,
            "buffer view is active; Update would reallocate the image",
            "itklib_update"};
        }
    }
}
