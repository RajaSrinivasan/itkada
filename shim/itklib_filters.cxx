#include "itklib_internal.hpp"

#include "itkBinaryThresholdImageFilter.h"
#include "itkExtractImageFilter.h"
#include "itkFlipImageFilter.h"
#include "itkGradientMagnitudeImageFilter.h"
#include "itkIdentityTransform.h"
#include "itkImage.h"
#include "itkImageToImageFilter.h"
#include "itkLinearInterpolateImageFunction.h"
#include "itkMedianImageFilter.h"
#include "itkResampleImageFilter.h"
#include "itkRescaleIntensityImageFilter.h"
#include "itkShrinkImageFilter.h"
#include "itkStatisticsImageFilter.h"

#include <cmath>
#include <cstdint>
#include <limits>
#include <type_traits>

namespace {

template <unsigned Dimension>
using Image_Type = itk::Image<std::uint16_t, Dimension>;

std::uint16_t
as_u16 (double value, const char * where)
{
  if (!std::isfinite (value))
    {
      throw itklib_status{ITKLIB_E_ARG, "value is not finite", where};
    }
  const long long rounded = std::llround (value);
  if (rounded < 0 || rounded > 65535)
    {
      throw itklib_status{ITKLIB_E_ARG, "value is outside UInt16 range", where};
    }
  return static_cast<std::uint16_t> (rounded);
}

template <unsigned Dimension, typename Filter_Type>
Filter_Type *
as_filter (itklib_object * filter, int klass, const char * where)
{
  if (filter == nullptr || filter->obj == nullptr || filter->klass != klass
      || filter->dim != Dimension || filter->pixel != ITKLIB_UINT16)
    {
      throw itklib_status{ITKLIB_E_ARG, "handle has the wrong filter type", where};
    }
  auto * concrete = dynamic_cast<Filter_Type *> (filter->obj);
  if (concrete == nullptr)
    {
      throw itklib_status{ITKLIB_E_ARG, "handle has the wrong filter type", where};
    }
  return concrete;
}

template <unsigned Dimension>
void
median_new (itklib_object ** out)
{
  using Filter_Type = itk::MedianImageFilter<Image_Type<Dimension>, Image_Type<Dimension>>;
  auto filter = Filter_Type::New ();
  *out = itklib_adopt (filter.GetPointer (), ITKLIB_UINT16, Dimension,
                       ITKLIB_CLASS_MEDIAN, true);
}

template <unsigned Dimension>
void
threshold_new (itklib_object ** out)
{
  using Filter_Type =
    itk::BinaryThresholdImageFilter<Image_Type<Dimension>, Image_Type<Dimension>>;
  auto filter = Filter_Type::New ();
  *out = itklib_adopt (filter.GetPointer (), ITKLIB_UINT16, Dimension,
                       ITKLIB_CLASS_THRESHOLD, true);
}

template <unsigned Dimension>
void
rescale_new (itklib_object ** out)
{
  using Filter_Type =
    itk::RescaleIntensityImageFilter<Image_Type<Dimension>, Image_Type<Dimension>>;
  auto filter = Filter_Type::New ();
  *out = itklib_adopt (filter.GetPointer (), ITKLIB_UINT16, Dimension,
                       ITKLIB_CLASS_RESCALE, true);
}

template <unsigned Dimension>
void
shrink_new (itklib_object ** out)
{
  using Filter_Type = itk::ShrinkImageFilter<Image_Type<Dimension>, Image_Type<Dimension>>;
  auto filter = Filter_Type::New ();
  *out = itklib_adopt (filter.GetPointer (), ITKLIB_UINT16, Dimension,
                       ITKLIB_CLASS_SHRINK, true);
}

/* Output size is not known until the upstream image has been updated.
   A plain ResampleImageFilter wants that size up front, so adaimg's
   uniform scale goes through this filter and is applied in
   GenerateOutputInformation. Explicit size/spacing still works for tests. */
template <unsigned Dimension>
class Uniform_Resample
  : public itk::ImageToImageFilter<Image_Type<Dimension>, Image_Type<Dimension>>
{
public:
  using Self = Uniform_Resample;
  using Superclass =
    itk::ImageToImageFilter<Image_Type<Dimension>, Image_Type<Dimension>>;
  using Pointer = itk::SmartPointer<Self>;
  using SizeType = typename Image_Type<Dimension>::SizeType;
  using SpacingType = typename Image_Type<Dimension>::SpacingType;
  using PointType = typename Image_Type<Dimension>::PointType;
  using DirectionType = typename Image_Type<Dimension>::DirectionType;

  itkNewMacro (Self);
  itkTypeMacro (Uniform_Resample, ImageToImageFilter);

  void SetUniformScale (double scale)
  {
    if (scale <= 0.0)
      {
        throw itklib_status{ITKLIB_E_ARG, "resample scale must be positive",
                            "itklib_resample_set_uniform_scale"};
      }
    use_scale_ = true;
    scale_ = scale;
    this->Modified ();
  }

  void SetExplicit (const SizeType & size, const SpacingType & spacing,
                    const PointType & origin, const DirectionType & direction,
                    std::uint16_t fill)
  {
    use_scale_ = false;
    explicit_size_ = size;
    explicit_spacing_ = spacing;
    explicit_origin_ = origin;
    explicit_direction_ = direction;
    fill_ = fill;
    explicit_ready_ = true;
    this->Modified ();
  }

protected:
  Uniform_Resample () = default;
  ~Uniform_Resample () override = default;

  void GenerateInputRequestedRegion () override
  {
    auto * input = const_cast<Image_Type<Dimension> *> (this->GetInput ());
    if (input != nullptr)
      {
        input->SetRequestedRegionToLargestPossibleRegion ();
      }
  }

  void GenerateOutputInformation () override
  {
    Superclass::GenerateOutputInformation ();
    auto * input = this->GetInput ();
    auto * output = this->GetOutput ();
    if (input == nullptr || output == nullptr)
      {
        return;
      }
    const auto in_region = input->GetLargestPossibleRegion ();
    SizeType size;
    SpacingType spacing;
    if (use_scale_)
      {
        for (unsigned axis = 0; axis < Dimension; ++axis)
          {
            const auto rounded = std::llround (
              static_cast<double> (in_region.GetSize (axis)) * scale_);
            size[axis] = static_cast<itk::SizeValueType> (rounded < 1 ? 1 : rounded);
            spacing[axis] = input->GetSpacing ()[axis] / scale_;
          }
        output->SetOrigin (input->GetOrigin ());
        output->SetDirection (input->GetDirection ());
      }
    else if (explicit_ready_)
      {
        size = explicit_size_;
        spacing = explicit_spacing_;
        output->SetOrigin (explicit_origin_);
        output->SetDirection (explicit_direction_);
      }
    else
      {
        return;
      }
    typename Image_Type<Dimension>::IndexType index;
    index.Fill (0);
    typename Image_Type<Dimension>::RegionType region;
    region.SetIndex (index);
    region.SetSize (size);
    output->SetSpacing (spacing);
    output->SetLargestPossibleRegion (region);
    output->SetRequestedRegion (region);
    output->SetBufferedRegion (region);
  }

  void GenerateData () override
  {
    using Resample_Type =
      itk::ResampleImageFilter<Image_Type<Dimension>, Image_Type<Dimension>, double>;
    using Interpolator_Type =
      itk::LinearInterpolateImageFunction<Image_Type<Dimension>, double>;
    using Transform_Type = itk::IdentityTransform<double, Dimension>;
    auto resample = Resample_Type::New ();
    resample->SetInput (this->GetInput ());
    resample->SetInterpolator (Interpolator_Type::New ());
    resample->SetTransform (Transform_Type::New ());
    resample->SetDefaultPixelValue (fill_);
    const auto region = this->GetOutput ()->GetLargestPossibleRegion ();
    resample->SetSize (region.GetSize ());
    resample->SetOutputSpacing (this->GetOutput ()->GetSpacing ());
    resample->SetOutputOrigin (this->GetOutput ()->GetOrigin ());
    resample->SetOutputDirection (this->GetOutput ()->GetDirection ());
    resample->Update ();
    this->GraftOutput (resample->GetOutput ());
  }

private:
  bool use_scale_ = false;
  bool explicit_ready_ = false;
  double scale_ = 1.0;
  std::uint16_t fill_ = 0;
  SizeType explicit_size_{};
  SpacingType explicit_spacing_{};
  PointType explicit_origin_{};
  DirectionType explicit_direction_{};
};

template <unsigned Dimension>
void
resample_new (itklib_object ** out)
{
  auto filter = Uniform_Resample<Dimension>::New ();
  *out = itklib_adopt (filter.GetPointer (), ITKLIB_UINT16, Dimension,
                       ITKLIB_CLASS_RESAMPLE, true);
}

template <unsigned Dimension>
void
flip_new (itklib_object ** out)
{
  using Filter_Type = itk::FlipImageFilter<Image_Type<Dimension>>;
  auto filter = Filter_Type::New ();
  *out = itklib_adopt (filter.GetPointer (), ITKLIB_UINT16, Dimension,
                       ITKLIB_CLASS_FLIP, true);
}

template <unsigned Dimension>
void
extract_new (itklib_object ** out)
{
  using Filter_Type =
    itk::ExtractImageFilter<Image_Type<Dimension>, Image_Type<Dimension>>;
  auto filter = Filter_Type::New ();
  /* Same input and output dimension does not collapse. Setting the
     strategy keeps a later size-1 axis from throwing. */
  filter->SetDirectionCollapseToSubmatrix ();
  *out = itklib_adopt (filter.GetPointer (), ITKLIB_UINT16, Dimension,
                       ITKLIB_CLASS_EXTRACT, true);
}

template <unsigned Dimension>
void
gradient_new (itklib_object ** out)
{
  using Filter_Type =
    itk::GradientMagnitudeImageFilter<Image_Type<Dimension>, Image_Type<Dimension>>;
  auto filter = Filter_Type::New ();
  *out = itklib_adopt (filter.GetPointer (), ITKLIB_UINT16, Dimension,
                       ITKLIB_CLASS_GRADIENT, true);
}

template <unsigned Dimension>
void
statistics_new (itklib_object ** out)
{
  using Filter_Type = itk::StatisticsImageFilter<Image_Type<Dimension>>;
  auto filter = Filter_Type::New ();
  *out = itklib_adopt (filter.GetPointer (), ITKLIB_UINT16, Dimension,
                       ITKLIB_CLASS_STATISTICS, true);
}

} // namespace

extern "C" int
itklib_filter_new (int kind, itklib_pixel_id pixel, unsigned dimension,
                   itklib_object ** out, itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (out == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "output pointer is null",
                            "itklib_filter_new"};
      }
    *out = nullptr;
    itklib_require_built (pixel, dimension);
    const bool three = dimension == 3;
    switch (kind)
      {
      case ITKLIB_FILTER_MEDIAN:
        three ? median_new<3> (out) : median_new<2> (out);
        break;
      case ITKLIB_FILTER_THRESHOLD:
        three ? threshold_new<3> (out) : threshold_new<2> (out);
        break;
      case ITKLIB_FILTER_RESCALE:
        three ? rescale_new<3> (out) : rescale_new<2> (out);
        break;
      case ITKLIB_FILTER_SHRINK:
        three ? shrink_new<3> (out) : shrink_new<2> (out);
        break;
      case ITKLIB_FILTER_RESAMPLE:
        three ? resample_new<3> (out) : resample_new<2> (out);
        break;
      case ITKLIB_FILTER_FLIP:
        three ? flip_new<3> (out) : flip_new<2> (out);
        break;
      case ITKLIB_FILTER_EXTRACT:
        three ? extract_new<3> (out) : extract_new<2> (out);
        break;
      case ITKLIB_FILTER_GRADIENT:
        three ? gradient_new<3> (out) : gradient_new<2> (out);
        break;
      case ITKLIB_FILTER_STATISTICS:
        three ? statistics_new<3> (out) : statistics_new<2> (out);
        break;
      default:
        throw itklib_status{ITKLIB_E_ARG, "unknown filter kind", "itklib_filter_new"};
      }
  });
}

extern "C" int
itklib_median_set_radius (itklib_object * filter, const uint64_t * radius,
                          itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (radius == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null radius", "itklib_median_set_radius"};
      }
    auto apply = [&] (auto * concrete) {
      using Filter_Type = std::remove_pointer_t<decltype (concrete)>;
      constexpr unsigned Dimension = Filter_Type::ImageDimension;
      typename Filter_Type::RadiusType value;
      for (unsigned axis = 0; axis < Dimension; ++axis)
        {
          if (radius[axis] > std::numeric_limits<itk::SizeValueType>::max ())
            {
              throw itklib_status{ITKLIB_E_ARG, "median radius is too large",
                                  "itklib_median_set_radius"};
            }
          value[axis] = static_cast<itk::SizeValueType> (radius[axis]);
        }
      concrete->SetRadius (value);
    };
    if (filter != nullptr && filter->dim == 3)
      {
        apply (as_filter<3, itk::MedianImageFilter<Image_Type<3>, Image_Type<3>>> (
          filter, ITKLIB_CLASS_MEDIAN, "itklib_median_set_radius"));
      }
    else
      {
        apply (as_filter<2, itk::MedianImageFilter<Image_Type<2>, Image_Type<2>>> (
          filter, ITKLIB_CLASS_MEDIAN, "itklib_median_set_radius"));
      }
  });
}

extern "C" int
itklib_threshold_set (itklib_object * filter, double lower, double upper,
                      double inside_value, double outside_value, itklib_error * error)
{
  return itklib_guard (error, [&] {
    const auto lo = as_u16 (lower, "itklib_threshold_set");
    const auto hi = as_u16 (upper, "itklib_threshold_set");
    const auto inside = as_u16 (inside_value, "itklib_threshold_set");
    const auto outside = as_u16 (outside_value, "itklib_threshold_set");
    if (lo > hi)
      {
        throw itklib_status{ITKLIB_E_ARG, "lower threshold exceeds upper threshold",
                            "itklib_threshold_set"};
      }
    auto apply = [&] (auto * concrete) {
      concrete->SetLowerThreshold (lo);
      concrete->SetUpperThreshold (hi);
      concrete->SetInsideValue (inside);
      concrete->SetOutsideValue (outside);
    };
    if (filter != nullptr && filter->dim == 3)
      {
        apply (as_filter<3, itk::BinaryThresholdImageFilter<Image_Type<3>, Image_Type<3>>> (
          filter, ITKLIB_CLASS_THRESHOLD, "itklib_threshold_set"));
      }
    else
      {
        apply (as_filter<2, itk::BinaryThresholdImageFilter<Image_Type<2>, Image_Type<2>>> (
          filter, ITKLIB_CLASS_THRESHOLD, "itklib_threshold_set"));
      }
  });
}

extern "C" int
itklib_rescale_set_output_range (itklib_object * filter, double minimum,
                                 double maximum, itklib_error * error)
{
  return itklib_guard (error, [&] {
    const auto lo = as_u16 (minimum, "itklib_rescale_set_output_range");
    const auto hi = as_u16 (maximum, "itklib_rescale_set_output_range");
    auto apply = [&] (auto * concrete) {
      concrete->SetOutputMinimum (lo);
      concrete->SetOutputMaximum (hi);
    };
    if (filter != nullptr && filter->dim == 3)
      {
        apply (as_filter<3, itk::RescaleIntensityImageFilter<Image_Type<3>, Image_Type<3>>> (
          filter, ITKLIB_CLASS_RESCALE, "itklib_rescale_set_output_range"));
      }
    else
      {
        apply (as_filter<2, itk::RescaleIntensityImageFilter<Image_Type<2>, Image_Type<2>>> (
          filter, ITKLIB_CLASS_RESCALE, "itklib_rescale_set_output_range"));
      }
  });
}

extern "C" int
itklib_shrink_set_factors (itklib_object * filter, const uint64_t * factors,
                           itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (factors == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null shrink factors",
                            "itklib_shrink_set_factors"};
      }
    auto apply = [&] (auto * concrete) {
      using Filter_Type = std::remove_pointer_t<decltype (concrete)>;
      typename Filter_Type::ShrinkFactorsType value;
      constexpr unsigned Dimension = Filter_Type::ImageDimension;
      for (unsigned axis = 0; axis < Dimension; ++axis)
        {
          if (factors[axis] == 0
              || factors[axis] > std::numeric_limits<unsigned int>::max ())
            {
              throw itklib_status{ITKLIB_E_ARG, "shrink factor must be a positive int",
                                  "itklib_shrink_set_factors"};
            }
          value[axis] = static_cast<unsigned int> (factors[axis]);
        }
      concrete->SetShrinkFactors (value);
    };
    if (filter != nullptr && filter->dim == 3)
      {
        apply (as_filter<3, itk::ShrinkImageFilter<Image_Type<3>, Image_Type<3>>> (
          filter, ITKLIB_CLASS_SHRINK, "itklib_shrink_set_factors"));
      }
    else
      {
        apply (as_filter<2, itk::ShrinkImageFilter<Image_Type<2>, Image_Type<2>>> (
          filter, ITKLIB_CLASS_SHRINK, "itklib_shrink_set_factors"));
      }
  });
}

extern "C" int
itklib_resample_configure (itklib_object * filter, const uint64_t * size,
                           const double * spacing, const double * origin,
                           const double * direction, double default_pixel,
                           itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (size == nullptr || spacing == nullptr || origin == nullptr
        || direction == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null resample geometry",
                            "itklib_resample_configure"};
      }
    const auto fill = as_u16 (default_pixel, "itklib_resample_configure");
    auto apply = [&] (auto * concrete) {
      using Filter_Type = std::remove_pointer_t<decltype (concrete)>;
      constexpr unsigned Dimension = Filter_Type::SizeType::Dimension;
      typename Filter_Type::SizeType extent;
      typename Filter_Type::SpacingType space;
      typename Filter_Type::PointType start;
      typename Filter_Type::DirectionType matrix;
      for (unsigned axis = 0; axis < Dimension; ++axis)
        {
          if (size[axis] == 0)
            {
              throw itklib_status{ITKLIB_E_ARG, "resample size must be non-zero",
                                  "itklib_resample_configure"};
            }
          extent[axis] = size[axis];
          space[axis] = spacing[axis];
          start[axis] = origin[axis];
        }
      for (unsigned row = 0; row < Dimension; ++row)
        {
          for (unsigned column = 0; column < Dimension; ++column)
            {
              matrix (row, column) = direction[row * Dimension + column];
            }
        }
      concrete->SetExplicit (extent, space, start, matrix, fill);
    };
    if (filter != nullptr && filter->dim == 3)
      {
        apply (as_filter<3, Uniform_Resample<3>> (
          filter, ITKLIB_CLASS_RESAMPLE, "itklib_resample_configure"));
      }
    else
      {
        apply (as_filter<2, Uniform_Resample<2>> (
          filter, ITKLIB_CLASS_RESAMPLE, "itklib_resample_configure"));
      }
  });
}

extern "C" int
itklib_resample_set_uniform_scale (itklib_object * filter, double scale,
                                   itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (filter != nullptr && filter->dim == 3)
      {
        as_filter<3, Uniform_Resample<3>> (
          filter, ITKLIB_CLASS_RESAMPLE, "itklib_resample_set_uniform_scale")
          ->SetUniformScale (scale);
      }
    else
      {
        as_filter<2, Uniform_Resample<2>> (
          filter, ITKLIB_CLASS_RESAMPLE, "itklib_resample_set_uniform_scale")
          ->SetUniformScale (scale);
      }
  });
}

extern "C" int
itklib_flip_set_axes (itklib_object * filter, const int * axes, int about_origin,
                      itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (axes == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null flip axes", "itklib_flip_set_axes"};
      }
    auto apply = [&] (auto * concrete) {
      using Filter_Type = std::remove_pointer_t<decltype (concrete)>;
      constexpr unsigned Dimension = Filter_Type::ImageDimension;
      typename Filter_Type::FlipAxesArrayType value;
      for (unsigned axis = 0; axis < Dimension; ++axis)
        {
          value[axis] = axes[axis] != 0;
        }
      concrete->SetFlipAxes (value);
      concrete->SetFlipAboutOrigin (about_origin != 0);
    };
    if (filter != nullptr && filter->dim == 3)
      {
        apply (as_filter<3, itk::FlipImageFilter<Image_Type<3>>> (
          filter, ITKLIB_CLASS_FLIP, "itklib_flip_set_axes"));
      }
    else
      {
        apply (as_filter<2, itk::FlipImageFilter<Image_Type<2>>> (
          filter, ITKLIB_CLASS_FLIP, "itklib_flip_set_axes"));
      }
  });
}

extern "C" int
itklib_extract_set_region (itklib_object * filter, const int64_t * index,
                           const uint64_t * size, itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (index == nullptr || size == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null extraction region",
                            "itklib_extract_set_region"};
      }
    auto apply = [&] (auto * concrete) {
      using Filter_Type = std::remove_pointer_t<decltype (concrete)>;
      constexpr unsigned Dimension = Filter_Type::InputImageDimension;
      typename Filter_Type::InputImageRegionType region;
      typename Image_Type<Dimension>::IndexType start;
      typename Image_Type<Dimension>::SizeType extent;
      for (unsigned axis = 0; axis < Dimension; ++axis)
        {
          if (size[axis] == 0)
            {
              throw itklib_status{ITKLIB_E_ARG, "extraction size must be non-zero",
                                  "itklib_extract_set_region"};
            }
          start[axis] = index[axis];
          extent[axis] = size[axis];
        }
      region.SetIndex (start);
      region.SetSize (extent);
      concrete->SetExtractionRegion (region);
    };
    if (filter != nullptr && filter->dim == 3)
      {
        apply (as_filter<3, itk::ExtractImageFilter<Image_Type<3>, Image_Type<3>>> (
          filter, ITKLIB_CLASS_EXTRACT, "itklib_extract_set_region"));
      }
    else
      {
        apply (as_filter<2, itk::ExtractImageFilter<Image_Type<2>, Image_Type<2>>> (
          filter, ITKLIB_CLASS_EXTRACT, "itklib_extract_set_region"));
      }
  });
}

extern "C" int
itklib_gradient_set_use_image_spacing (itklib_object * filter, int enabled,
                                       itklib_error * error)
{
  return itklib_guard (error, [&] {
    auto apply = [&] (auto * concrete) {
      concrete->SetUseImageSpacing (enabled != 0);
    };
    if (filter != nullptr && filter->dim == 3)
      {
        apply (as_filter<3, itk::GradientMagnitudeImageFilter<Image_Type<3>, Image_Type<3>>> (
          filter, ITKLIB_CLASS_GRADIENT, "itklib_gradient_set_use_image_spacing"));
      }
    else
      {
        apply (as_filter<2, itk::GradientMagnitudeImageFilter<Image_Type<2>, Image_Type<2>>> (
          filter, ITKLIB_CLASS_GRADIENT, "itklib_gradient_set_use_image_spacing"));
      }
  });
}

extern "C" int
itklib_statistics_get (itklib_object * filter, double * minimum, double * maximum,
                       double * mean, itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (minimum == nullptr || maximum == nullptr || mean == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null statistics outputs",
                            "itklib_statistics_get"};
      }
    auto apply = [&] (auto * concrete) {
      *minimum = static_cast<double> (concrete->GetMinimum ());
      *maximum = static_cast<double> (concrete->GetMaximum ());
      *mean = static_cast<double> (concrete->GetMean ());
    };
    if (filter != nullptr && filter->dim == 3)
      {
        apply (as_filter<3, itk::StatisticsImageFilter<Image_Type<3>>> (
          filter, ITKLIB_CLASS_STATISTICS, "itklib_statistics_get"));
      }
    else
      {
        apply (as_filter<2, itk::StatisticsImageFilter<Image_Type<2>>> (
          filter, ITKLIB_CLASS_STATISTICS, "itklib_statistics_get"));
      }
  });
}
