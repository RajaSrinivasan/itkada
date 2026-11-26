with Ada.Finalization;
with Interfaces;
with Itklib.Pixel_Signature;
with System;

generic
   with package Sig is new Itklib.Pixel_Signature (<>);
   Dimension : Positive;
package Itklib.Images with SPARK_Mode => Off is
   --  itk::Image<TPixel, VImageDimension>. The handle is a controlled
   --  reference: copying it calls Register, and finalizing calls
   --  UnRegister. The buffer is the ITK buffer (x varies fastest).

   subtype Pixel is Sig.Pixel_Type;
   Pixel_Kind_Id : constant Itklib.Pixel_Kind := Sig.Pixel_Kind_Id;
   Image_Dimension : constant Positive := Dimension;

   subtype Axis is Positive range 1 .. Dimension;

   type Index is array (Axis) of Interfaces.Integer_64;
   type Size is array (Axis) of Interfaces.Unsigned_64;
   type Vector is array (Axis) of Long_Float;
   type Direction is array (Axis, Axis) of Long_Float;
   type Region is record
      Start : Index;
      Extent : Size;
   end record;

   type Image is tagged private;

   function Create (Extent : Size) return Image;
   function Largest_Possible_Region (Img : Image) return Region;
   function Reference_Count (Img : Image) return Natural;

   function Spacing (Img : Image) return Vector;
   function Origin (Img : Image) return Vector;
   function Image_Direction (Img : Image) return Direction;
   procedure Set_Spacing (Img : in out Image; Value : Vector);
   procedure Set_Origin (Img : in out Image; Value : Vector);
   procedure Set_Direction (Img : in out Image; Value : Direction);

   --  Zero-copy view of GetBufferPointer. The view is valid only for
   --  the call, and only until the next Update that reallocates.
   type Pixel_Array is array (Interfaces.Unsigned_64 range <>) of aliased Pixel
     with Convention => C;

   generic
      with procedure Process (Data : in out Pixel_Array);
   procedure With_Buffer (Img : in out Image);

   --  Binding support. Handle must already carry the one reference this
   --  Image will own.
   function From_Handle (Handle : System.Address) return Image;
   function Raw_Handle (Img : Image) return System.Address;

private
   type Image is new Ada.Finalization.Controlled with record
      Handle : System.Address := System.Null_Address;
   end record;

   overriding procedure Adjust (Img : in out Image);
   overriding procedure Finalize (Img : in out Image);
end Itklib.Images;
