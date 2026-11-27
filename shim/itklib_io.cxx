#include "itklib_internal.hpp"

#include "itkImage.h"
#include "itkImageFileReader.h"
#include "itkImageFileWriter.h"
#include "itkPNGImageIO.h"

#include <cstdint>
#include <string>

namespace {

template <unsigned Dimension>
using Image_Type = itk::Image<std::uint16_t, Dimension>;

template <unsigned Dimension>
void
reader_new (itklib_object ** out)
{
  using Reader_Type = itk::ImageFileReader<Image_Type<Dimension>>;
  auto reader = Reader_Type::New ();
  auto png = itk::PNGImageIO::New ();
  reader->SetImageIO (png.GetPointer ());
  *out = itklib_adopt (reader.GetPointer (), ITKLIB_UINT16, Dimension,
                       ITKLIB_CLASS_READER, true);
}

template <unsigned Dimension>
void
writer_new (itklib_object ** out)
{
  using Writer_Type = itk::ImageFileWriter<Image_Type<Dimension>>;
  auto writer = Writer_Type::New ();
  auto png = itk::PNGImageIO::New ();
  writer->SetImageIO (png.GetPointer ());
  *out = itklib_adopt (writer.GetPointer (), ITKLIB_UINT16, Dimension,
                       ITKLIB_CLASS_WRITER, true);
}

template <unsigned Dimension>
void
reader_set_file (itklib_object * reader, const char * path)
{
  using Reader_Type = itk::ImageFileReader<Image_Type<Dimension>>;
  auto * concrete = dynamic_cast<Reader_Type *> (reader->obj);
  if (concrete == nullptr)
    {
      throw itklib_status{ITKLIB_E_ARG, "handle is not a UInt16 reader",
                          "itklib_reader_set_file"};
    }
  concrete->SetFileName (path);
}

template <unsigned Dimension>
void
writer_set_file (itklib_object * writer, const char * path)
{
  using Writer_Type = itk::ImageFileWriter<Image_Type<Dimension>>;
  auto * concrete = dynamic_cast<Writer_Type *> (writer->obj);
  if (concrete == nullptr)
    {
      throw itklib_status{ITKLIB_E_ARG, "handle is not a UInt16 writer",
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

template class itk::ImageFileReader<itk::Image<std::uint16_t, 2>>;
template class itk::ImageFileReader<itk::Image<std::uint16_t, 3>>;
template class itk::ImageFileWriter<itk::Image<std::uint16_t, 2>>;
template class itk::ImageFileWriter<itk::Image<std::uint16_t, 3>>;

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
    if (dimension == 2)
      {
        reader_new<2> (out);
      }
    else
      {
        reader_new<3> (out);
      }
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
    if (dimension == 2)
      {
        writer_new<2> (out);
      }
    else
      {
        writer_new<3> (out);
      }
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
    if (reader->dim == 2)
      {
        reader_set_file<2> (reader, path);
      }
    else
      {
        reader_set_file<3> (reader, path);
      }
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
    if (writer->dim == 2)
      {
        writer_set_file<2> (writer, path);
      }
    else
      {
        writer_set_file<3> (writer, path);
      }
  });
}
