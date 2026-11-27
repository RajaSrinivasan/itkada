with Interfaces.C;
with Itklib.Thin;

package body Itklib.Images with SPARK_Mode => Off is
   use type Interfaces.Unsigned_64;
   use type System.Address;

   overriding procedure Adjust (Img : in out Image) is
   begin
      Thin.Register (Img.Handle);
   end Adjust;

   overriding procedure Finalize (Img : in out Image) is
      Handle : constant System.Address := Img.Handle;
   begin
      Img.Handle := System.Null_Address;
      Thin.Unregister (Handle);
   end Finalize;

   function Raw_Handle (Img : Image) return System.Address is
   begin
      return Img.Handle;
   end Raw_Handle;

   function From_Handle (Handle : System.Address) return Image is
      Result : Image;
   begin
      Result.Handle := Handle;
      return Result;
   end From_Handle;

   function Create (Extent : Size) return Image is
      Raw : Thin.Extent_Array (1 .. Dimension);
      K : Positive := 1;
      Result : Image;
   begin
      for Item of Extent loop
         if Item = 0 then
            raise Itk_Error with "image extent must be non-zero";
         end if;
         Raw (K) := Item;
         K := K + 1;
      end loop;
      Result.Handle := Thin.Image_New (Pixel_Kind_Id, Raw);
      return Result;
   end Create;

   procedure Read_Geometry
     (Img : Image; Start : out Index; Extent : out Size; Space : out Vector;
      Start_Point : out Vector; Matrix : out Direction)
   is
      C_Index : Thin.Index_Array (1 .. Dimension);
      C_Size : Thin.Extent_Array (1 .. Dimension);
      C_Space : Thin.Double_Array (1 .. Dimension);
      C_Origin : Thin.Double_Array (1 .. Dimension);
      C_Direction : Thin.Double_Array (1 .. Dimension * Dimension);
      Slot : Positive := 1;
   begin
      Thin.Image_Get_Geometry
        (Img.Handle, C_Index, C_Size, C_Space, C_Origin, C_Direction);
      for Axis_Id in Axis loop
         Start (Axis_Id) := C_Index (Positive (Axis_Id));
         Extent (Axis_Id) := C_Size (Positive (Axis_Id));
         Space (Axis_Id) := Long_Float (C_Space (Positive (Axis_Id)));
         Start_Point (Axis_Id) := Long_Float (C_Origin (Positive (Axis_Id)));
      end loop;
      for Row in Axis loop
         for Column in Axis loop
            Matrix (Row, Column) := Long_Float (C_Direction (Slot));
            Slot := Slot + 1;
         end loop;
      end loop;
   end Read_Geometry;

   function Largest_Possible_Region (Img : Image) return Region is
      Start : Index;
      Extent : Size;
      Space : Vector;
      Start_Point : Vector;
      Matrix : Direction;
   begin
      Read_Geometry (Img, Start, Extent, Space, Start_Point, Matrix);
      return (Start => Start, Extent => Extent);
   end Largest_Possible_Region;

   function Reference_Count (Img : Image) return Natural is
   begin
      return Thin.Reference_Count (Img.Handle);
   end Reference_Count;

   function Spacing (Img : Image) return Vector is
      Start : Index;
      Extent : Size;
      Space : Vector;
      Start_Point : Vector;
      Matrix : Direction;
   begin
      Read_Geometry (Img, Start, Extent, Space, Start_Point, Matrix);
      return Space;
   end Spacing;

   function Origin (Img : Image) return Vector is
      Start : Index;
      Extent : Size;
      Space : Vector;
      Start_Point : Vector;
      Matrix : Direction;
   begin
      Read_Geometry (Img, Start, Extent, Space, Start_Point, Matrix);
      return Start_Point;
   end Origin;

   function Image_Direction (Img : Image) return Direction is
      Start : Index;
      Extent : Size;
      Space : Vector;
      Start_Point : Vector;
      Matrix : Direction;
   begin
      Read_Geometry (Img, Start, Extent, Space, Start_Point, Matrix);
      return Matrix;
   end Image_Direction;

   function To_Doubles (Value : Vector) return Thin.Double_Array is
      Raw : Thin.Double_Array (1 .. Dimension);
      K : Positive := 1;
   begin
      for Item of Value loop
         Raw (K) := Interfaces.C.double (Item);
         K := K + 1;
      end loop;
      return Raw;
   end To_Doubles;

   procedure Set_Spacing (Img : in out Image; Value : Vector) is
   begin
      Thin.Image_Set_Spacing (Img.Handle, To_Doubles (Value));
   end Set_Spacing;

   procedure Set_Origin (Img : in out Image; Value : Vector) is
   begin
      Thin.Image_Set_Origin (Img.Handle, To_Doubles (Value));
   end Set_Origin;

   procedure Set_Direction (Img : in out Image; Value : Direction) is
      Raw : Thin.Double_Array (1 .. Dimension * Dimension);
      K : Positive := 1;
   begin
      for Row in Axis loop
         for Column in Axis loop
            Raw (K) := Interfaces.C.double (Value (Row, Column));
            K := K + 1;
         end loop;
      end loop;
      Thin.Image_Set_Direction (Img.Handle, Raw);
   end Set_Direction;

   procedure With_Buffer (Img : in out Image) is
      Count : Interfaces.Unsigned_64 := 0;
      Ptr : System.Address := System.Null_Address;
   begin
      Thin.Image_Buffer_Lock (Img.Handle);
      begin
         Thin.Image_Buffer (Img.Handle, Ptr, Count);
         if Count = 0 or else Ptr = System.Null_Address then
            declare
               Empty : Pixel_Array (1 .. 0);
            begin
               Process (Empty);
            end;
         else
            declare
               Data : Pixel_Array (0 .. Count - 1);
               pragma Import (C, Data);
               for Data'Address use Ptr;
            begin
               Process (Data);
            end;
         end if;
         Thin.Image_Buffer_Unlock (Img.Handle);
      exception
         when others =>
            Thin.Image_Buffer_Unlock (Img.Handle);
            raise;
      end;
   end With_Buffer;

   function To_Index (Value : Index) return Thin.Index_Array is
      Raw : Thin.Index_Array (1 .. Dimension);
      K : Positive := 1;
   begin
      for Item of Value loop
         Raw (K) := Item;
         K := K + 1;
      end loop;
      return Raw;
   end To_Index;

   function Transform_Index_To_Physical_Point
     (Img : Image; Idx : Index) return Vector
   is
      Point : Thin.Double_Array (1 .. Dimension);
      Result : Vector;
   begin
      Thin.Image_Index_To_Physical (Img.Handle, To_Index (Idx), Point);
      for Axis_Id in Axis loop
         Result (Axis_Id) := Long_Float (Point (Positive (Axis_Id)));
      end loop;
      return Result;
   end Transform_Index_To_Physical_Point;

   function Transform_Physical_Point_To_Index
     (Img : Image; Point : Vector) return Index
   is
      Raw : Thin.Index_Array (1 .. Dimension);
      Result : Index;
   begin
      Thin.Image_Physical_To_Index (Img.Handle, To_Doubles (Point), Raw);
      for Axis_Id in Axis loop
         Result (Axis_Id) := Raw (Positive (Axis_Id));
      end loop;
      return Result;
   end Transform_Physical_Point_To_Index;

   procedure Disconnect_Pipeline (Img : in out Image) is
   begin
      Thin.Image_Disconnect (Img.Handle);
   end Disconnect_Pipeline;

begin
   if not Itklib.Thin.Is_Supported (Pixel_Kind_Id, Dimension) then
      raise Unsupported_Instantiation
        with "ITK image is not built for this pixel kind and dimension";
   end if;
end Itklib.Images;
