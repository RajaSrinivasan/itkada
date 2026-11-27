#include "itklib_internal.hpp"

#include "itkImage.h"
#include "itkImageFileWriter.h"
#include "itkImageSource.h"
#include "itkImageToImageFilter.h"
#include "itkStatisticsImageFilter.h"

#include <cstdint>

namespace {

template <unsigned Dimension>
using Image_Type = itk::Image<std::uint16_t, Dimension>;

template <unsigned Dimension>
void
set_input (itklib_object * filter, itklib_object * image)
{
  if (filter->klass == ITKLIB_CLASS_READER)
    {
      throw itklib_status{ITKLIB_E_ARG, "a reader does not take an image input",
                          "itklib_set_input"};
    }
  auto * concrete = dynamic_cast<Image_Type<Dimension> *> (image->obj);
  if (concrete == nullptr || image->klass != ITKLIB_CLASS_IMAGE
      || image->pixel != ITKLIB_UINT16 || image->dim != Dimension
      || filter->pixel != ITKLIB_UINT16 || filter->dim != Dimension)
    {
      throw itklib_status{ITKLIB_E_ARG, "input is not a matching UInt16 image",
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
        dynamic_cast<itk::ImageFileWriter<Image_Type<Dimension>> *> (filter->obj);
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
        dynamic_cast<itk::StatisticsImageFilter<Image_Type<Dimension>> *> (filter->obj);
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
        itk::ImageToImageFilter<Image_Type<Dimension>, Image_Type<Dimension>>;
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

template <unsigned Dimension>
Image_Type<Dimension> *
output_of (itklib_object * process)
{
  if (process->klass == ITKLIB_CLASS_WRITER
      || process->klass == ITKLIB_CLASS_STATISTICS)
    {
      throw itklib_status{ITKLIB_E_ARG, "this object has no image output",
                          "itklib_get_output"};
    }
  using Source_Type = itk::ImageSource<Image_Type<Dimension>>;
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
    if (filter->dim == 2)
      {
        set_input<2> (filter, image);
      }
    else if (filter->dim == 3)
      {
        set_input<3> (filter, image);
      }
    else
      {
        throw itklib_status{ITKLIB_E_UNSUPPORTED, "unsupported dimension",
                            "itklib_set_input"};
      }
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
    if (process->dim == 2)
      {
        auto * out = output_of<2> (process);
        if (out == nullptr)
          {
            throw itklib_status{ITKLIB_E_NULL, "filter has no output image",
                                "itklib_get_output"};
          }
        *image = itklib_adopt (out, ITKLIB_UINT16, 2, ITKLIB_CLASS_IMAGE, false);
      }
    else if (process->dim == 3)
      {
        auto * out = output_of<3> (process);
        if (out == nullptr)
          {
            throw itklib_status{ITKLIB_E_NULL, "filter has no output image",
                                "itklib_get_output"};
          }
        *image = itklib_adopt (out, ITKLIB_UINT16, 3, ITKLIB_CLASS_IMAGE, false);
      }
    else
      {
        throw itklib_status{ITKLIB_E_UNSUPPORTED, "unsupported dimension",
                            "itklib_get_output"};
      }
    (*image)->anchor = process->obj;
    process->obj->Register ();
  });
}
