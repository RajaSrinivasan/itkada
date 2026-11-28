#include "itklib_internal.hpp"

#include "itkImage.h"

#include <cstdint>

namespace {

template <typename Pixel, unsigned Dimension>
itk::Image<Pixel, Dimension> *
as_image (itklib_object * wrap)
{
  using Image_Type = itk::Image<Pixel, Dimension>;
  if (wrap == nullptr || wrap->obj == nullptr || wrap->klass != ITKLIB_CLASS_IMAGE
      || wrap->pixel != Itklib_Pixel<Pixel>::Id || wrap->dim != Dimension)
    {
      return nullptr;
    }
  return dynamic_cast<Image_Type *> (wrap->obj);
}

template <typename Pixel, unsigned Dimension>
void
image_new (const uint64_t * size, itklib_object ** out)
{
  using Image_Type = itk::Image<Pixel, Dimension>;
  if (size == nullptr)
    {
      throw itklib_status{ITKLIB_E_NULL, "size pointer is null", "itklib_image_new"};
    }
  for (unsigned axis = 0; axis < Dimension; ++axis)
    {
      if (size[axis] == 0)
        {
          throw itklib_status{ITKLIB_E_ARG, "image extent must be non-zero",
                              "itklib_image_new"};
        }
    }

  auto image = Image_Type::New ();
  typename Image_Type::IndexType index;
  typename Image_Type::SizeType extent;
  index.Fill (0);
  for (unsigned axis = 0; axis < Dimension; ++axis)
    {
      extent[axis] = size[axis];
    }
  typename Image_Type::RegionType region;
  region.SetIndex (index);
  region.SetSize (extent);
  image->SetRegions (region);
  image->Allocate (true);
  *out = itklib_adopt (image.GetPointer (), Itklib_Pixel<Pixel>::Id, Dimension,
                       ITKLIB_CLASS_IMAGE, true);
}

template <typename Pixel, unsigned Dimension>
void
image_buffer (itklib_object * image, void ** data, uint64_t * count)
{
  auto * concrete = as_image<Pixel, Dimension> (image);
  if (concrete == nullptr)
    {
      throw itklib_status{ITKLIB_E_ARG, "handle is not a matching image",
                          "itklib_image_buffer"};
    }
  *count = concrete->GetBufferedRegion ().GetNumberOfPixels ();
  *data = concrete->GetBufferPointer ();
}

template <typename Pixel, unsigned Dimension>
void
image_get_geometry (itklib_object * image, int64_t * index, uint64_t * size,
                    double * spacing, double * origin, double * direction)
{
  auto * concrete = as_image<Pixel, Dimension> (image);
  if (concrete == nullptr)
    {
      throw itklib_status{ITKLIB_E_ARG, "handle is not a matching image",
                          "itklib_image_get_geometry"};
    }
  const auto region = concrete->GetLargestPossibleRegion ();
  const auto & space = concrete->GetSpacing ();
  const auto & start = concrete->GetOrigin ();
  const auto & matrix = concrete->GetDirection ();
  for (unsigned axis = 0; axis < Dimension; ++axis)
    {
      if (index != nullptr)
        {
          index[axis] = region.GetIndex (axis);
        }
      if (size != nullptr)
        {
          size[axis] = region.GetSize (axis);
        }
      if (spacing != nullptr)
        {
          spacing[axis] = space[axis];
        }
      if (origin != nullptr)
        {
          origin[axis] = start[axis];
        }
    }
  if (direction != nullptr)
    {
      for (unsigned row = 0; row < Dimension; ++row)
        {
          for (unsigned column = 0; column < Dimension; ++column)
            {
              direction[row * Dimension + column] = matrix (row, column);
            }
        }
    }
}

template <typename Pixel, unsigned Dimension>
void
image_set_spacing (itklib_object * image, const double * spacing)
{
  auto * concrete = as_image<Pixel, Dimension> (image);
  if (concrete == nullptr || spacing == nullptr)
    {
      throw itklib_status{ITKLIB_E_ARG, "invalid spacing arguments",
                          "itklib_image_set_spacing"};
    }
  typename itk::Image<Pixel, Dimension>::SpacingType value;
  for (unsigned axis = 0; axis < Dimension; ++axis)
    {
      value[axis] = spacing[axis];
    }
  concrete->SetSpacing (value);
}

template <typename Pixel, unsigned Dimension>
void
image_set_origin (itklib_object * image, const double * origin)
{
  auto * concrete = as_image<Pixel, Dimension> (image);
  if (concrete == nullptr || origin == nullptr)
    {
      throw itklib_status{ITKLIB_E_ARG, "invalid origin arguments",
                          "itklib_image_set_origin"};
    }
  typename itk::Image<Pixel, Dimension>::PointType value;
  for (unsigned axis = 0; axis < Dimension; ++axis)
    {
      value[axis] = origin[axis];
    }
  concrete->SetOrigin (value);
}

template <typename Pixel, unsigned Dimension>
void
image_set_direction (itklib_object * image, const double * direction)
{
  auto * concrete = as_image<Pixel, Dimension> (image);
  if (concrete == nullptr || direction == nullptr)
    {
      throw itklib_status{ITKLIB_E_ARG, "invalid direction arguments",
                          "itklib_image_set_direction"};
    }
  typename itk::Image<Pixel, Dimension>::DirectionType matrix;
  for (unsigned row = 0; row < Dimension; ++row)
    {
      for (unsigned column = 0; column < Dimension; ++column)
        {
          matrix (row, column) = direction[row * Dimension + column];
        }
    }
  concrete->SetDirection (matrix);
}

template <typename Pixel, unsigned Dimension>
void
image_index_to_physical (itklib_object * image, const int64_t * index,
                         double * point)
{
  auto * concrete = as_image<Pixel, Dimension> (image);
  if (concrete == nullptr || index == nullptr || point == nullptr)
    {
      throw itklib_status{ITKLIB_E_ARG, "invalid physical-point arguments",
                          "itklib_image_index_to_physical"};
    }
  typename itk::Image<Pixel, Dimension>::IndexType idx;
  typename itk::Image<Pixel, Dimension>::PointType physical;
  for (unsigned axis = 0; axis < Dimension; ++axis)
    {
      idx[axis] = index[axis];
    }
  concrete->TransformIndexToPhysicalPoint (idx, physical);
  for (unsigned axis = 0; axis < Dimension; ++axis)
    {
      point[axis] = physical[axis];
    }
}

template <typename Pixel, unsigned Dimension>
void
image_physical_to_index (itklib_object * image, const double * point,
                         int64_t * index)
{
  auto * concrete = as_image<Pixel, Dimension> (image);
  if (concrete == nullptr || point == nullptr || index == nullptr)
    {
      throw itklib_status{ITKLIB_E_ARG, "invalid index arguments",
                          "itklib_image_physical_to_index"};
    }
  typename itk::Image<Pixel, Dimension>::PointType physical;
  typename itk::Image<Pixel, Dimension>::IndexType idx;
  for (unsigned axis = 0; axis < Dimension; ++axis)
    {
      physical[axis] = point[axis];
    }
  concrete->TransformPhysicalPointToIndex (physical, idx);
  for (unsigned axis = 0; axis < Dimension; ++axis)
    {
      index[axis] = idx[axis];
    }
}

} // namespace

extern "C" int
itklib_image_new (itklib_pixel_id pixel, unsigned dimension, const uint64_t * size,
                  itklib_object ** out, itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (out == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "output pointer is null",
                            "itklib_image_new"};
      }
    *out = nullptr;
    itklib_require_built (pixel, dimension);
    itklib_visit_builtin (pixel, dimension, [&] (auto pixel_tag, auto dim_tag) {
      using Pixel = typename decltype (pixel_tag)::type;
      constexpr unsigned Dimension = decltype (dim_tag)::value;
      image_new<Pixel, Dimension> (size, out);
    });
  });
}

extern "C" int
itklib_image_buffer (itklib_object * image, void ** data, uint64_t * count,
                     itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (data == nullptr || count == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "buffer output pointer is null",
                            "itklib_image_buffer"};
      }
    *data = nullptr;
    *count = 0;
    if (image == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null image", "itklib_image_buffer"};
      }
    itklib_visit_builtin (image->pixel, image->dim, [&] (auto pixel_tag, auto dim_tag) {
      using Pixel = typename decltype (pixel_tag)::type;
      constexpr unsigned Dimension = decltype (dim_tag)::value;
      image_buffer<Pixel, Dimension> (image, data, count);
    });
  });
}

extern "C" int
itklib_image_get_geometry (itklib_object * image, int64_t * index, uint64_t * size,
                           double * spacing, double * origin, double * direction,
                           itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (image == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null image",
                            "itklib_image_get_geometry"};
      }
    itklib_visit_builtin (image->pixel, image->dim, [&] (auto pixel_tag, auto dim_tag) {
      using Pixel = typename decltype (pixel_tag)::type;
      constexpr unsigned Dimension = decltype (dim_tag)::value;
      image_get_geometry<Pixel, Dimension> (image, index, size, spacing, origin, direction);
    });
  });
}

extern "C" int
itklib_image_set_spacing (itklib_object * image, const double * spacing,
                          itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (image == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null image", "itklib_image_set_spacing"};
      }
    itklib_visit_builtin (image->pixel, image->dim, [&] (auto pixel_tag, auto dim_tag) {
      using Pixel = typename decltype (pixel_tag)::type;
      constexpr unsigned Dimension = decltype (dim_tag)::value;
      image_set_spacing<Pixel, Dimension> (image, spacing);
    });
  });
}

extern "C" int
itklib_image_set_origin (itklib_object * image, const double * origin,
                         itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (image == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null image", "itklib_image_set_origin"};
      }
    itklib_visit_builtin (image->pixel, image->dim, [&] (auto pixel_tag, auto dim_tag) {
      using Pixel = typename decltype (pixel_tag)::type;
      constexpr unsigned Dimension = decltype (dim_tag)::value;
      image_set_origin<Pixel, Dimension> (image, origin);
    });
  });
}

extern "C" int
itklib_image_set_direction (itklib_object * image, const double * direction,
                            itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (image == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null image",
                            "itklib_image_set_direction"};
      }
    itklib_visit_builtin (image->pixel, image->dim, [&] (auto pixel_tag, auto dim_tag) {
      using Pixel = typename decltype (pixel_tag)::type;
      constexpr unsigned Dimension = decltype (dim_tag)::value;
      image_set_direction<Pixel, Dimension> (image, direction);
    });
  });
}

extern "C" int
itklib_image_buffer_lock (itklib_object * image, itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (image == nullptr || image->obj == nullptr
        || image->klass != ITKLIB_CLASS_IMAGE)
      {
        throw itklib_status{ITKLIB_E_ARG, "buffer lock needs an image",
                            "itklib_image_buffer_lock"};
      }
    itklib_buffer_lock_add (image->obj, 1);
  });
}

extern "C" int
itklib_image_buffer_unlock (itklib_object * image, itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (image == nullptr || image->obj == nullptr
        || image->klass != ITKLIB_CLASS_IMAGE)
      {
        throw itklib_status{ITKLIB_E_ARG, "buffer unlock needs an image",
                            "itklib_image_buffer_unlock"};
      }
    itklib_buffer_lock_add (image->obj, -1);
  });
}

extern "C" int
itklib_image_disconnect (itklib_object * image, itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (image == nullptr || image->obj == nullptr
        || image->klass != ITKLIB_CLASS_IMAGE)
      {
        throw itklib_status{ITKLIB_E_ARG, "disconnect needs an image",
                            "itklib_image_disconnect"};
      }
    auto * data = dynamic_cast<itk::DataObject *> (image->obj);
    if (data == nullptr)
      {
        throw itklib_status{ITKLIB_E_ARG, "handle is not a data object",
                            "itklib_image_disconnect"};
      }
    data->DisconnectPipeline ();
    if (image->anchor != nullptr)
      {
        itk::LightObject * anchor = image->anchor;
        const int refs = image->refs.load (std::memory_order_relaxed);
        image->anchor = nullptr;
        for (int count = 0; count < refs; ++count)
          {
            anchor->UnRegister ();
          }
      }
  });
}

extern "C" int
itklib_image_index_to_physical (itklib_object * image, const int64_t * index,
                                double * point, itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (image == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null image",
                            "itklib_image_index_to_physical"};
      }
    itklib_visit_builtin (image->pixel, image->dim, [&] (auto pixel_tag, auto dim_tag) {
      using Pixel = typename decltype (pixel_tag)::type;
      constexpr unsigned Dimension = decltype (dim_tag)::value;
      image_index_to_physical<Pixel, Dimension> (image, index, point);
    });
  });
}

extern "C" int
itklib_image_physical_to_index (itklib_object * image, const double * point,
                                int64_t * index, itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (image == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null image",
                            "itklib_image_physical_to_index"};
      }
    itklib_visit_builtin (image->pixel, image->dim, [&] (auto pixel_tag, auto dim_tag) {
      using Pixel = typename decltype (pixel_tag)::type;
      constexpr unsigned Dimension = decltype (dim_tag)::value;
      image_physical_to_index<Pixel, Dimension> (image, point, index);
    });
  });
}
