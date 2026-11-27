generic
   type Pixel is private;
   Kind : Itklib.Pixel_Kind;
package Itklib.Pixel_Signature with SPARK_Mode => On is
   pragma Compile_Time_Error
     (not ((Kind = Itklib.UInt8 and then Pixel'Size = 8)
           or else (Kind = Itklib.Int8 and then Pixel'Size = 8)
           or else (Kind = Itklib.UInt16 and then Pixel'Size = 16)
           or else (Kind = Itklib.Int16 and then Pixel'Size = 16)
           or else (Kind = Itklib.UInt32 and then Pixel'Size = 32)
           or else (Kind = Itklib.Int32 and then Pixel'Size = 32)
           or else (Kind = Itklib.UInt64 and then Pixel'Size = 64)
           or else (Kind = Itklib.Int64 and then Pixel'Size = 64)
           or else (Kind = Itklib.Float32 and then Pixel'Size = 32)
           or else (Kind = Itklib.Float64 and then Pixel'Size = 64)),
     "Pixel size does not match Kind");

   subtype Pixel_Type is Pixel;
   Pixel_Kind_Id : constant Itklib.Pixel_Kind := Kind;
end Itklib.Pixel_Signature;
