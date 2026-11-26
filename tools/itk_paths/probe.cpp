#include "itkDiscreteGaussianImageFilter.h"
#include "itkImage.h"
#include "itkImageFileReader.h"
#include "itkImageFileWriter.h"
#include "itkPNGImageIO.h"
#include "itkVersion.h"

extern "C" int
itklib_itk_probe ()
{
  using Image_Type = itk::Image<unsigned short, 2>;
  auto image = Image_Type::New ();
  auto reader = itk::ImageFileReader<Image_Type>::New ();
  auto writer = itk::ImageFileWriter<Image_Type>::New ();
  auto png = itk::PNGImageIO::New ();
  auto smooth =
    itk::DiscreteGaussianImageFilter<Image_Type, Image_Type>::New ();
  reader->SetImageIO (png.GetPointer ());
  writer->SetImageIO (png.GetPointer ());
  (void) image;
  (void) smooth;
  return itk::Version::GetITKMajorVersion ();
}
