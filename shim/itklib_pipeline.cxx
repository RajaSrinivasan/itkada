#include "itklib_internal.hpp"

#include "itkDiscreteGaussianImageFilter.h"
#include "itkImage.h"
#include "itkImageFileReader.h"
#include "itkImageFileWriter.h"

#include <cstdint>

namespace {

template <unsigned Dimension>
using Image_Type = itk::Image<std::uint16_t, Dimension>;

template <unsigned Dimension>
void
set_input (itklib_object * filter, itklib_object * image)
{
  auto * concrete = dynamic_cast<Image_Type<Dimension> *> (image->obj);
  if (concrete == nullptr || image->klass != ITKLIB_CLASS_IMAGE
      || image->pixel != ITKLIB_UINT16 || image->dim != Dimension)
    {
      throw itklib_status{ITKLIB_E_ARG, "input is not a matching UInt16 image",
                          "itklib_set_input"};
    }
  if (filter->klass == ITKLIB_CLASS_WRITER)
    {
      using Writer_Type = itk::ImageFileWriter<Image_Type<Dimension>>;
      auto * writer = dynamic_cast<Writer_Type *> (filter->obj);
      if (writer == nullptr)
        {
          throw itklib_status{ITKLIB_E_ARG, "handle is not a writer",
                              "itklib_set_input"};
        }
      writer->SetInput (concrete);
      return;
    }
  if (filter->klass == ITKLIB_CLASS_GAUSSIAN)
    {
      using Filter_Type = itk::DiscreteGaussianImageFilter<Image_Type<Dimension>,
                                                           Image_Type<Dimension>>;
      auto * smooth = dynamic_cast<Filter_Type *> (filter->obj);
      if (smooth == nullptr)
        {
          throw itklib_status{ITKLIB_E_ARG, "handle is not a gaussian filter",
                              "itklib_set_input"};
        }
      smooth->SetInput (concrete);
      return;
    }
  throw itklib_status{ITKLIB_E_ARG, "this object does not accept an image input",
                      "itklib_set_input"};
}

template <unsigned Dimension>
Image_Type<Dimension> *
output_of (itklib_object * process)
{
  if (process->klass == ITKLIB_CLASS_READER)
    {
      using Reader_Type = itk::ImageFileReader<Image_Type<Dimension>>;
      auto * reader = dynamic_cast<Reader_Type *> (process->obj);
      if (reader == nullptr)
        {
          throw itklib_status{ITKLIB_E_ARG, "handle is not a reader",
                              "itklib_get_output"};
        }
      return reader->GetOutput ();
    }
  if (process->klass == ITKLIB_CLASS_GAUSSIAN)
    {
      using Filter_Type = itk::DiscreteGaussianImageFilter<Image_Type<Dimension>,
                                                           Image_Type<Dimension>>;
      auto * smooth = dynamic_cast<Filter_Type *> (process->obj);
      if (smooth == nullptr)
        {
          throw itklib_status{ITKLIB_E_ARG, "handle is not a gaussian filter",
                              "itklib_get_output"};
        }
      return smooth->GetOutput ();
    }
  throw itklib_status{ITKLIB_E_ARG, "this object has no image output",
                      "itklib_get_output"};
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
    itk::Image<std::uint16_t, 2> * out2 = nullptr;
    itk::Image<std::uint16_t, 3> * out3 = nullptr;
    if (process->dim == 2)
      {
        out2 = output_of<2> (process);
        if (out2 == nullptr)
          {
            throw itklib_status{ITKLIB_E_NULL, "filter has no output image",
                                "itklib_get_output"};
          }
        *image = itklib_adopt (out2, ITKLIB_UINT16, 2, ITKLIB_CLASS_IMAGE, false);
      }
    else if (process->dim == 3)
      {
        out3 = output_of<3> (process);
        if (out3 == nullptr)
          {
            throw itklib_status{ITKLIB_E_NULL, "filter has no output image",
                                "itklib_get_output"};
          }
        *image = itklib_adopt (out3, ITKLIB_UINT16, 3, ITKLIB_CLASS_IMAGE, false);
      }
    else
      {
        throw itklib_status{ITKLIB_E_UNSUPPORTED, "unsupported dimension",
                            "itklib_get_output"};
      }
  });
}
