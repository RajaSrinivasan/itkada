with Ada.Finalization;
with Interfaces;
with Itklib.Core.Regions;
with Itklib.Pixel_Signature;
with System;

generic
   with package Sig is new Itklib.Pixel_Signature (<>);
   Dimension : Positive;
package Itklib.Images with SPARK_Mode => Off is
   --  itk::Image<TPixel, VImageDimension>. The handle is a controlled
   --  reference: copying it calls Register, and finalizing calls
   --  UnRegister. The buffer is the ITK buffer (x varies fastest).
   --  Index, size, and region arithmetic is Itklib.Core.Regions, which
   --  is SPARK. This package itself calls C, so it stays SPARK_Mode Off.

   subtype Pixel is Sig.Pixel_Type;
   Pixel_Kind_Id : constant Itklib.Pixel_Kind := Sig.Pixel_Kind_Id;
   Image_Dimension : constant Positive := Dimension;

   package Regions is new Itklib.Core.Regions (Dimension);

   subtype Axis is Regions.Axis;
   subtype Index is Regions.Index;
   subtype Size is Regions.Size;
   subtype Vector is Regions.Vector;
   subtype Direction is Regions.Matrix;
   subtype Region is Regions.Region;

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

   --  ITK index is absolute. physical = origin + direction * (spacing .* index).
   function Transform_Index_To_Physical_Point
     (Img : Image; Idx : Index) return Vector;
   function Transform_Physical_Point_To_Index
     (Img : Image; Point : Vector) return Index;

   --  Drop the pipeline source. The pixel buffer stays with this handle.
   --  Other Ada copies may still anchor the producer until they finalize.
   procedure Disconnect_Pipeline (Img : in out Image);

   --  Zero-copy view of GetBufferPointer. The view is valid only inside
   --  Process. A lock is held for that call; Update of a filter whose
   --  output is this image raises Itk_Error while the view is active.
   --  Do not keep the array after Process returns. x varies fastest.
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
