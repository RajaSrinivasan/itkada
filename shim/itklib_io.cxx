#include "itklib_internal.hpp"

#include "itkImage.h"
#include "itkImageFileReader.h"
#include "itkImageFileWriter.h"
#include "itkPNGImageIO.h"

#include <cstdint>
#include <string>

namespace {

template <typename Pixel, unsigned Dimension>
using Image_Type = itk::Image<Pixel, Dimension>;

template <typename Pixel, unsigned Dimension>
void
reader_new (itklib_object ** out)
{
  using Reader_Type = itk::ImageFileReader<Image_Type<Pixel, Dimension>>;
  auto reader = Reader_Type::New ();
  auto png = itk::PNGImageIO::New ();
  reader->SetImageIO (png.GetPointer ());
  *out = itklib_adopt (reader.GetPointer (), Itklib_Pixel<Pixel>::Id, Dimension,
                       ITKLIB_CLASS_READER, true);
}

template <typename Pixel, unsigned Dimension>
void
writer_new (itklib_object ** out)
{
  using Writer_Type = itk::ImageFileWriter<Image_Type<Pixel, Dimension>>;
  auto writer = Writer_Type::New ();
  auto png = itk::PNGImageIO::New ();
  writer->SetImageIO (png.GetPointer ());
  *out = itklib_adopt (writer.GetPointer (), Itklib_Pixel<Pixel>::Id, Dimension,
                       ITKLIB_CLASS_WRITER, true);
}

template <typename Pixel, unsigned Dimension>
void
reader_set_file (itklib_object * reader, const char * path)
{
  using Reader_Type = itk::ImageFileReader<Image_Type<Pixel, Dimension>>;
  auto * concrete = dynamic_cast<Reader_Type *> (reader->obj);
  if (concrete == nullptr)
    {
      throw itklib_status{ITKLIB_E_ARG, "handle is not a matching reader",
                          "itklib_reader_set_file"};
    }
  concrete->SetFileName (path);
}

template <typename Pixel, unsigned Dimension>
void
writer_set_file (itklib_object * writer, const char * path)
{
  using Writer_Type = itk::ImageFileWriter<Image_Type<Pixel, Dimension>>;
  auto * concrete = dynamic_cast<Writer_Type *> (writer->obj);
  if (concrete == nullptr)
    {
      throw itklib_status{ITKLIB_E_ARG, "handle is not a matching writer",
                          "itklib_writer_set_file"};
    }
  concrete->SetFileName (path);
}

void
require_path (const char * path, const char * where)
{
  if (path == nullptr || path[0] == '\0')
    {
      throw itklib_status{ITKLIB_E_ARG, "file name is empty", where};
    }
}

} // namespace


extern "C" int
itklib_reader_new (itklib_pixel_id pixel, unsigned dimension, itklib_object ** out,
                   itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (out == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "output pointer is null",
                            "itklib_reader_new"};
      }
    *out = nullptr;
    itklib_require_built (pixel, dimension);
    itklib_visit_builtin (pixel, dimension, [&] (auto pixel_tag, auto dim_tag) {
      using Pixel = typename decltype (pixel_tag)::type;
      constexpr unsigned Dimension = decltype (dim_tag)::value;
      reader_new<Pixel, Dimension> (out);
    });
  });
}

extern "C" int
itklib_writer_new (itklib_pixel_id pixel, unsigned dimension, itklib_object ** out,
                   itklib_error * error)
{
  return itklib_guard (error, [&] {
    if (out == nullptr)
      {
        throw itklib_status{ITKLIB_E_NULL, "output pointer is null",
                            "itklib_writer_new"};
      }
    *out = nullptr;
    itklib_require_built (pixel, dimension);
    if (!itklib_png_pixel (pixel))
      {
        throw itklib_status{
          ITKLIB_E_UNSUPPORTED,
          "PNG cannot store this pixel type; rescale or cast to an integer pixel before writing",
          "itklib_writer_new"};
      }
    itklib_visit_builtin (pixel, dimension, [&] (auto pixel_tag, auto dim_tag) {
      using Pixel = typename decltype (pixel_tag)::type;
      constexpr unsigned Dimension = decltype (dim_tag)::value;
      writer_new<Pixel, Dimension> (out);
    });
  });
}

extern "C" int
itklib_reader_set_file (itklib_object * reader, const char * path,
                        itklib_error * error)
{
  return itklib_guard (error, [&] {
    require_path (path, "itklib_reader_set_file");
    if (reader == nullptr || reader->obj == nullptr
        || reader->klass != ITKLIB_CLASS_READER)
      {
        throw itklib_status{ITKLIB_E_ARG, "handle is not a reader",
                            "itklib_reader_set_file"};
      }
    itklib_visit_builtin (reader->pixel, reader->dim, [&] (auto pixel_tag, auto dim_tag) {
      using Pixel = typename decltype (pixel_tag)::type;
      constexpr unsigned Dimension = decltype (dim_tag)::value;
      reader_set_file<Pixel, Dimension> (reader, path);
    });
  });
}

extern "C" int
itklib_writer_set_file (itklib_object * writer, const char * path,
                        itklib_error * error)
{
  return itklib_guard (error, [&] {
    require_path (path, "itklib_writer_set_file");
    if (writer == nullptr || writer->obj == nullptr
        || writer->klass != ITKLIB_CLASS_WRITER)
      {
        throw itklib_status{ITKLIB_E_ARG, "handle is not a writer",
                            "itklib_writer_set_file"};
      }
    itklib_visit_builtin (writer->pixel, writer->dim, [&] (auto pixel_tag, auto dim_tag) {
      using Pixel = typename decltype (pixel_tag)::type;
      constexpr unsigned Dimension = decltype (dim_tag)::value;
      writer_set_file<Pixel, Dimension> (writer, path);
    });
  });
}
