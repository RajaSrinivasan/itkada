with Interfaces;

generic
package Itklib.Images.Region_Iterators with SPARK_Mode => Off is
   --  Names from the Phase 1 API. The proved implementation is
   --  Itklib.Core.Regions (this image's Regions instance). This child
   --  cannot be SPARK_Mode On because Itklib.Images calls C.

   subtype Cursor is Regions.Cursor;

   function Fits (R : Region) return Boolean renames Regions.Fits;
   function Product_Bounded (Extent : Size) return Boolean
     renames Regions.Product_Bounded;
   function Volume (Extent : Size) return Interfaces.Unsigned_64
     renames Regions.Volume;
   function Inside (R : Region; Idx : Index) return Boolean renames Regions.Inside;
   function Offset (R : Region; Idx : Index) return Interfaces.Unsigned_64
     renames Regions.Offset;
   function Index_At (R : Region; Off : Interfaces.Unsigned_64) return Index
     renames Regions.Index_At;
   function First (R : Region) return Cursor renames Regions.First;
   function Has_Element (C : Cursor) return Boolean renames Regions.Has_Element;
   function Next (C : Cursor) return Cursor renames Regions.Next;
   function Offset_Of (C : Cursor) return Interfaces.Unsigned_64
     renames Regions.Offset_Of;
   function Index_Of (C : Cursor) return Index renames Regions.Index_Of;

   generic
      with procedure Visit (Idx : Index; Off : Interfaces.Unsigned_64);
   procedure Walk (R : Region);
end Itklib.Images.Region_Iterators;
