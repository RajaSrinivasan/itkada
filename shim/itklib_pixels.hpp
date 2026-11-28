#pragma once

#include "itklib.h"

#include <cstdint>

/* Maps every ITK scalar to its C enum. Instantiating a pixel still depends
   on the generated builtin table: traits exist for the whole scalar set so
   the generator can name them, and only matrix.yaml pixels are compiled in. */

template <typename T>
struct Itklib_Type
{
  using type = T;
};

template <unsigned N>
struct Itklib_Dim
{
  static constexpr unsigned value = N;
};

template <typename Pixel>
struct Itklib_Pixel;

template <>
struct Itklib_Pixel<std::uint8_t>
{
  static constexpr itklib_pixel_id Id = ITKLIB_UINT8;
  static constexpr bool Real = false;
  static constexpr const char * Name = "UInt8";
};

template <>
struct Itklib_Pixel<std::int8_t>
{
  static constexpr itklib_pixel_id Id = ITKLIB_INT8;
  static constexpr bool Real = false;
  static constexpr const char * Name = "Int8";
};

template <>
struct Itklib_Pixel<std::uint16_t>
{
  static constexpr itklib_pixel_id Id = ITKLIB_UINT16;
  static constexpr bool Real = false;
  static constexpr const char * Name = "UInt16";
};

template <>
struct Itklib_Pixel<std::int16_t>
{
  static constexpr itklib_pixel_id Id = ITKLIB_INT16;
  static constexpr bool Real = false;
  static constexpr const char * Name = "Int16";
};

template <>
struct Itklib_Pixel<std::uint32_t>
{
  static constexpr itklib_pixel_id Id = ITKLIB_UINT32;
  static constexpr bool Real = false;
  static constexpr const char * Name = "UInt32";
};

template <>
struct Itklib_Pixel<std::int32_t>
{
  static constexpr itklib_pixel_id Id = ITKLIB_INT32;
  static constexpr bool Real = false;
  static constexpr const char * Name = "Int32";
};

template <>
struct Itklib_Pixel<std::uint64_t>
{
  static constexpr itklib_pixel_id Id = ITKLIB_UINT64;
  static constexpr bool Real = false;
  static constexpr const char * Name = "UInt64";
};

template <>
struct Itklib_Pixel<std::int64_t>
{
  static constexpr itklib_pixel_id Id = ITKLIB_INT64;
  static constexpr bool Real = false;
  static constexpr const char * Name = "Int64";
};

template <>
struct Itklib_Pixel<float>
{
  static constexpr itklib_pixel_id Id = ITKLIB_FLOAT32;
  static constexpr bool Real = true;
  static constexpr const char * Name = "Float32";
};

template <>
struct Itklib_Pixel<double>
{
  static constexpr itklib_pixel_id Id = ITKLIB_FLOAT64;
  static constexpr bool Real = true;
  static constexpr const char * Name = "Float64";
};
