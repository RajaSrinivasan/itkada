#include "itklib_internal.hpp"

#include "itkDiscreteGaussianImageFilter.h"
#include "itkImage.h"

#include <cstdint>

namespace {

template <unsigned Dimension>
using Image_Type = itk::Image<std::uint16_t, Dimension>;

template <unsigned Dimension>
using Gaussian_Type =
  itk::DiscreteGaussianImageFilter<Image_Type<Dimension>, Image_Type<Dimension>>;

template <unsigned Dimension>
void
gaussian_new (itklib_object ** out)
{
  auto filter = Gaussian_Type<Dimension>::New ();
  *out = itklib_adopt (filter.GetPointer (), ITKLIB_UINT16, Dimension,
                       ITKLIB_CLASS_GAUSSIAN, true);
}

template <unsigned Dimension>
Gaussian_Type<Dimension> *
as_gaussian (itklib_object * filter)
{
  if (filter == nullptr || filter->obj == nullptr
      || filter->klass != ITKLIB_CLASS_GAUSSIAN || filter->dim != Dimension
      || filter->pixel != ITKLIB_UINT16)
    {
      return nullptr;
    }
  return dynamic_cast<Gaussian_Type<Dimension> *> (filter->obj);
}

} // namespace

template class itk::DiscreteGaussianImageFilter<itk::Image<std::uint16_t, 2>,
                                                itk::Image<std::uint16_t, 2>>;
template class itk::DiscreteGaussianImageFilter<itk::Image<std::uint16_t, 3>,
                                                itk::Image<std::uint16_t, 3>>;

extern "C" int
itklib_discrete_gaussian_new (itklib_pixel_id input_pixel,
                              itklib_pixel_id output_pixel, unsigned dimension,
                              itklib_object ** out, itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (out == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "output pointer is null",
                            "itklib_discrete_gaussian_new"};
      }
    *out = nullptr;
    if (input_pixel != output_pixel)
      {
        throw itklib_status{
          ITKLIB_E_UNSUPPORTED,
          "DiscreteGaussian is built only for identical input and output pixels",
          "itklib_discrete_gaussian_new"};
      }
    itklib_require_built (input_pixel, dimension);
    if (dimension == 2)
      {
        gaussian_new<2> (out);
      }
    else
      {
        gaussian_new<3> (out);
      }
  });
}

extern "C" int
itklib_discrete_gaussian_set_variance (itklib_object * filter,
                                       const double * variance,
                                       itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (filter == nullptr || variance == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null variance arguments",
                            "itklib_discrete_gaussian_set_variance"};
      }
    if (filter->dim == 2)
      {
        auto * concrete = as_gaussian<2> (filter);
        if (concrete == nullptr)
          {
            throw itklib_status{ITKLIB_E_ARG, "handle is not a UInt16 gaussian",
                                "itklib_discrete_gaussian_set_variance"};
          }
        concrete->SetVariance (variance);
      }
    else
      {
        auto * concrete = as_gaussian<3> (filter);
        if (concrete == nullptr)
          {
            throw itklib_status{ITKLIB_E_ARG, "handle is not a UInt16 gaussian",
                                "itklib_discrete_gaussian_set_variance"};
          }
        concrete->SetVariance (variance);
      }
  });
}

extern "C" int
itklib_discrete_gaussian_set_use_image_spacing (itklib_object * filter,
                                                int enabled, itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (filter == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null filter",
                            "itklib_discrete_gaussian_set_use_image_spacing"};
      }
    if (filter->dim == 2)
      {
        auto * concrete = as_gaussian<2> (filter);
        if (concrete == nullptr)
          {
            throw itklib_status{ITKLIB_E_ARG, "handle is not a UInt16 gaussian",
                                "itklib_discrete_gaussian_set_use_image_spacing"};
          }
        concrete->SetUseImageSpacing (enabled != 0);
      }
    else
      {
        auto * concrete = as_gaussian<3> (filter);
        if (concrete == nullptr)
          {
            throw itklib_status{ITKLIB_E_ARG, "handle is not a UInt16 gaussian",
                                "itklib_discrete_gaussian_set_use_image_spacing"};
          }
        concrete->SetUseImageSpacing (enabled != 0);
      }
  });
}

extern "C" int
itklib_discrete_gaussian_set_maximum_error (itklib_object * filter,
                                            const double * maximum_error,
                                            itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (filter == nullptr || maximum_error == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null maximum-error arguments",
                            "itklib_discrete_gaussian_set_maximum_error"};
      }
    if (filter->dim == 2)
      {
        auto * concrete = as_gaussian<2> (filter);
        if (concrete == nullptr)
          {
            throw itklib_status{ITKLIB_E_ARG, "handle is not a UInt16 gaussian",
                                "itklib_discrete_gaussian_set_maximum_error"};
          }
        concrete->SetMaximumError (maximum_error);
      }
    else
      {
        auto * concrete = as_gaussian<3> (filter);
        if (concrete == nullptr)
          {
            throw itklib_status{ITKLIB_E_ARG, "handle is not a UInt16 gaussian",
                                "itklib_discrete_gaussian_set_maximum_error"};
          }
        concrete->SetMaximumError (maximum_error);
      }
  });
}
