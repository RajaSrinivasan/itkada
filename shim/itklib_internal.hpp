#pragma once

#include "itklib.h"

#include "itkConfigure.h"
#include "itkEventObject.h"
#include "itkLightObject.h"
#include "itkMacro.h"
#include "itkObject.h"

#include <atomic>
#include <cstdint>
#include <cstring>
#include <new>
#include <string>
#include <utility>

enum {
  ITKLIB_CLASS_IMAGE = 1,
  ITKLIB_CLASS_READER = 2,
  ITKLIB_CLASS_WRITER = 3,
  ITKLIB_CLASS_GAUSSIAN = 4
};

struct itklib_object {
  itk::LightObject * obj;
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
