#include "itklib_internal.hpp"

#include "itkImage.h"

#include <cstdint>

namespace {

template <unsigned Dimension>
itk::Image<std::uint16_t, Dimension> *
as_image (itklib_object * wrap)
{
  using Image_Type = itk::Image<std::uint16_t, Dimension>;
  if (wrap == nullptr || wrap->obj == nullptr || wrap->klass != ITKLIB_CLASS_IMAGE
      || wrap->pixel != ITKLIB_UINT16 || wrap->dim != Dimension)
    {
      return nullptr;
    }
  return dynamic_cast<Image_Type *> (wrap->obj);
}

template <unsigned Dimension>
void
image_new (const uint64_t * size, itklib_object ** out)
{
  using Image_Type = itk::Image<std::uint16_t, Dimension>;
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
  *out = itklib_adopt (image.GetPointer (), ITKLIB_UINT16, Dimension,
                       ITKLIB_CLASS_IMAGE, true);
}

template <unsigned Dimension>
void
image_buffer (itklib_object * image, void ** data, uint64_t * count)
{
  auto * concrete = as_image<Dimension> (image);
  if (concrete == nullptr)
    {
      throw itklib_status{ITKLIB_E_ARG, "handle is not a UInt16 image",
                          "itklib_image_buffer"};
    }
  *count = concrete->GetBufferedRegion ().GetNumberOfPixels ();
  *data = concrete->GetBufferPointer ();
}

template <unsigned Dimension>
void
image_get_geometry (itklib_object * image, int64_t * index, uint64_t * size,
                    double * spacing, double * origin, double * direction)
{
  auto * concrete = as_image<Dimension> (image);
  if (concrete == nullptr)
    {
      throw itklib_status{ITKLIB_E_ARG, "handle is not a UInt16 image",
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

template <unsigned Dimension>
void
image_set_spacing (itklib_object * image, const double * spacing)
{
  auto * concrete = as_image<Dimension> (image);
  if (concrete == nullptr || spacing == nullptr)
    {
      throw itklib_status{ITKLIB_E_ARG, "invalid spacing arguments",
                          "itklib_image_set_spacing"};
    }
  typename itk::Image<std::uint16_t, Dimension>::SpacingType value;
  for (unsigned axis = 0; axis < Dimension; ++axis)
    {
      value[axis] = spacing[axis];
    }
  concrete->SetSpacing (value);
}

template <unsigned Dimension>
void
image_set_origin (itklib_object * image, const double * origin)
{
  auto * concrete = as_image<Dimension> (image);
  if (concrete == nullptr || origin == nullptr)
    {
      throw itklib_status{ITKLIB_E_ARG, "invalid origin arguments",
                          "itklib_image_set_origin"};
    }
  typename itk::Image<std::uint16_t, Dimension>::PointType value;
  for (unsigned axis = 0; axis < Dimension; ++axis)
    {
      value[axis] = origin[axis];
    }
  concrete->SetOrigin (value);
}

template <unsigned Dimension>
void
image_set_direction (itklib_object * image, const double * direction)
{
  auto * concrete = as_image<Dimension> (image);
  if (concrete == nullptr || direction == nullptr)
    {
      throw itklib_status{ITKLIB_E_ARG, "invalid direction arguments",
                          "itklib_image_set_direction"};
    }
  typename itk::Image<std::uint16_t, Dimension>::DirectionType matrix;
  for (unsigned row = 0; row < Dimension; ++row)
    {
      for (unsigned column = 0; column < Dimension; ++column)
        {
          matrix (row, column) = direction[row * Dimension + column];
        }
    }
  concrete->SetDirection (matrix);
}

} // namespace

/* Explicit Phase 0 instances. The functions below instantiate them too. */
template class itk::Image<std::uint16_t, 2>;
template class itk::Image<std::uint16_t, 3>;

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
    if (dimension == 2)
      {
        image_new<2> (size, out);
      }
    else
      {
        image_new<3> (size, out);
      }
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
    if (image->dim == 2)
      {
        image_buffer<2> (image, data, count);
      }
    else if (image->dim == 3)
      {
        image_buffer<3> (image, data, count);
      }
    else
      {
        throw itklib_status{ITKLIB_E_UNSUPPORTED, "unsupported image dimension",
                            "itklib_image_buffer"};
      }
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
    if (image->dim == 2)
      {
        image_get_geometry<2> (image, index, size, spacing, origin, direction);
      }
    else if (image->dim == 3)
      {
        image_get_geometry<3> (image, index, size, spacing, origin, direction);
      }
    else
      {
        throw itklib_status{ITKLIB_E_UNSUPPORTED, "unsupported image dimension",
                            "itklib_image_get_geometry"};
      }
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
    if (image->dim == 2)
      {
        image_set_spacing<2> (image, spacing);
      }
    else
      {
        image_set_spacing<3> (image, spacing);
      }
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
    if (image->dim == 2)
      {
        image_set_origin<2> (image, origin);
      }
    else
      {
        image_set_origin<3> (image, origin);
      }
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
    if (image->dim == 2)
      {
        image_set_direction<2> (image, direction);
      }
    else
      {
        image_set_direction<3> (image, direction);
      }
  });
}
