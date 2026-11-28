#include "itklib_internal.hpp"

#include "itkImage.h"
#include "itkImageFileWriter.h"
#include "itkImageSource.h"
#include "itkImageToImageFilter.h"
#include "itkStatisticsImageFilter.h"

#include <cstdint>

namespace {

template <typename Pixel, unsigned Dimension>
using Image_Type = itk::Image<Pixel, Dimension>;

template <typename Pixel, unsigned Dimension>
void
set_input (itklib_object * filter, itklib_object * image)
{
  if (filter->klass == ITKLIB_CLASS_READER)
    {
      throw itklib_status{ITKLIB_E_ARG, "a reader does not take an image input",
                          "itklib_set_input"};
    }
  auto * concrete = dynamic_cast<Image_Type<Pixel, Dimension> *> (image->obj);
  if (concrete == nullptr || image->klass != ITKLIB_CLASS_IMAGE
      || image->pixel != Itklib_Pixel<Pixel>::Id || image->dim != Dimension
      || filter->pixel != Itklib_Pixel<Pixel>::Id || filter->dim != Dimension)
    {
      throw itklib_status{ITKLIB_E_ARG, "input is not a matching image",
                          "itklib_set_input"};
    }
  auto * process = dynamic_cast<itk::ProcessObject *> (filter->obj);
  if (process == nullptr)
    {
      throw itklib_status{ITKLIB_E_ARG, "handle is not a process object",
                          "itklib_set_input"};
    }
  if (filter->klass == ITKLIB_CLASS_WRITER)
    {
      auto * writer =
        dynamic_cast<itk::ImageFileWriter<Image_Type<Pixel, Dimension>> *> (filter->obj);
      if (writer == nullptr)
        {
          throw itklib_status{ITKLIB_E_ARG, "handle is not a writer",
                              "itklib_set_input"};
        }
      writer->SetInput (concrete);
    }
  else if (filter->klass == ITKLIB_CLASS_STATISTICS)
    {
      auto * stats =
        dynamic_cast<itk::StatisticsImageFilter<Image_Type<Pixel, Dimension>> *> (filter->obj);
      if (stats == nullptr)
        {
          throw itklib_status{ITKLIB_E_ARG, "handle is not a statistics filter",
                              "itklib_set_input"};
        }
      stats->SetInput (concrete);
    }
  else
    {
      using Base_Type =
        itk::ImageToImageFilter<Image_Type<Pixel, Dimension>, Image_Type<Pixel, Dimension>>;
      auto * base = dynamic_cast<Base_Type *> (filter->obj);
      if (base == nullptr)
        {
          throw itklib_status{ITKLIB_E_ARG,
                              "this object does not accept an image input",
                              "itklib_set_input"};
        }
      base->SetInput (concrete);
    }
  itklib_retain_source (process, concrete);
}

template <typename Pixel, unsigned Dimension>
Image_Type<Pixel, Dimension> *
output_of (itklib_object * process)
{
  if (process->klass == ITKLIB_CLASS_WRITER
      || process->klass == ITKLIB_CLASS_STATISTICS)
    {
      throw itklib_status{ITKLIB_E_ARG, "this object has no image output",
                          "itklib_get_output"};
    }
  using Source_Type = itk::ImageSource<Image_Type<Pixel, Dimension>>;
  auto * source = dynamic_cast<Source_Type *> (process->obj);
  if (source == nullptr)
    {
      throw itklib_status{ITKLIB_E_ARG, "handle has no image output",
                          "itklib_get_output"};
    }
  return source->GetOutput ();
}

} // namespace

extern "C" int
itklib_set_input (itklib_object * filter, unsigned index, itklib_object * image,
                  itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (index != 0)
      {
        throw itklib_status{ITKLIB_E_ARG, "only input 0 is implemented",
                            "itklib_set_input"};
      }
    if (filter == nullptr || filter->obj == nullptr || image == nullptr
        || image->obj == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null filter or image",
                            "itklib_set_input"};
      }
    itklib_visit_builtin (filter->pixel, filter->dim, [&] (auto pixel_tag, auto dim_tag) {
      using Pixel = typename decltype (pixel_tag)::type;
      constexpr unsigned Dimension = decltype (dim_tag)::value;
      set_input<Pixel, Dimension> (filter, image);
    });
  });
}

extern "C" int
itklib_get_output (itklib_object * process, unsigned index, itklib_object ** image,
                   itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (image == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "output pointer is null",
                            "itklib_get_output"};
      }
    *image = nullptr;
    if (index != 0)
      {
        throw itklib_status{ITKLIB_E_ARG, "only output 0 is implemented",
                            "itklib_get_output"};
      }
    if (process == nullptr || process->obj == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "null process object",
                            "itklib_get_output"};
      }
    itklib_visit_builtin (process->output_pixel, process->dim,
                          [&] (auto pixel_tag, auto dim_tag) {
      using Pixel = typename decltype (pixel_tag)::type;
      constexpr unsigned Dimension = decltype (dim_tag)::value;
      auto * out = output_of<Pixel, Dimension> (process);
      if (out == nullptr)
        {
          throw itklib_status{ITKLIB_E_NULL, "filter has no output image",
                              "itklib_get_output"};
        }
      *image = itklib_adopt (out, Itklib_Pixel<Pixel>::Id, Dimension,
                             ITKLIB_CLASS_IMAGE, false);
    });
    (*image)->anchor = process->obj;
    process->obj->Register ();
  });
}
