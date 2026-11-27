with Interfaces;

generic
   Dimension : Positive;
package Itklib.Core.Regions with SPARK_Mode => On is
   --  Index, size, and region arithmetic in ITK buffer order: axis 1
   --  (x) varies fastest. Iterators walk that order. Geometry helpers
   --  use the same axis numbering. No C++.

   use type Interfaces.Integer_64;
   use type Interfaces.Unsigned_64;

   subtype Axis is Positive range 1 .. Dimension;

   type Index is array (Axis) of Interfaces.Integer_64;
   type Size is array (Axis) of Interfaces.Unsigned_64;
   type Vector is array (Axis) of Long_Float;
   type Matrix is array (Axis, Axis) of Long_Float;

   type Region is record
      Start : Index;
      Extent : Size;
   end record;

   function Fits (R : Region) return Boolean is
     (for all A in Axis =>
        R.Extent (A) > 0
        and then R.Extent (A) <= Interfaces.Unsigned_64 (Interfaces.Integer_64'Last)
        and then R.Start (A) <=
          Interfaces.Integer_64'Last - Interfaces.Integer_64 (R.Extent (A)))
   with Global => null;

   function Product_Bounded (Extent : Size) return Boolean with
     Global => null;

   function Volume (Extent : Size) return Interfaces.Unsigned_64 with
     Pre => Product_Bounded (Extent),
     Post => Volume'Result >= 1,
     Global => null;

   function Difference_Fits
     (Start : Interfaces.Integer_64; Idx : Interfaces.Integer_64) return Boolean
   is
     (Idx >= Start
      and then (Start >= 0 or else Idx <= Interfaces.Integer_64'Last + Start))
   with Global => null;

   function Inside (R : Region; Idx : Index) return Boolean is
     (for all A in Axis =>
        Difference_Fits (R.Start (A), Idx (A))
        and then Interfaces.Unsigned_64 (Idx (A) - R.Start (A)) < R.Extent (A))
   with Pre => Fits (R), Global => null;

   function Offset (R : Region; Idx : Index) return Interfaces.Unsigned_64 with
     Pre => Fits (R) and then Product_Bounded (R.Extent) and then Inside (R, Idx),
     Global => null;

   function Index_At
     (R : Region; Off : Interfaces.Unsigned_64) return Index
   with
     Pre => Fits (R) and then Product_Bounded (R.Extent) and then Off < Volume (R.Extent),
     Global => null;

   type Cursor is record
      Subject : Region;
      Off : Interfaces.Unsigned_64 := 0;
      At_End : Boolean := True;
   end record;

   function Has_Element (C : Cursor) return Boolean is (not C.At_End) with
     Global => null;

   function First (R : Region) return Cursor with
     Pre => Fits (R) and then Product_Bounded (R.Extent),
     Post => Has_Element (First'Result) and then First'Result.Off = 0
       and then First'Result.Subject = R,
     Global => null;

   function Next (C : Cursor) return Cursor with
     Pre => Has_Element (C) and then Fits (C.Subject)
       and then Product_Bounded (C.Subject.Extent)
       and then C.Off < Volume (C.Subject.Extent),
     Post => Next'Result.Subject = C.Subject,
     Global => null;

   function Offset_Of (C : Cursor) return Interfaces.Unsigned_64 is (C.Off) with
     Pre => Has_Element (C), Global => null;

   function Index_Of (C : Cursor) return Index with
     Pre => Has_Element (C) and then Fits (C.Subject)
       and then Product_Bounded (C.Subject.Extent)
       and then C.Off < Volume (C.Subject.Extent),
     Post => Index_Of'Result = Index_At (C.Subject, C.Off),
     Global => null;

   generic
      with procedure Visit (Idx : Index; Off : Interfaces.Unsigned_64);
   procedure Walk (R : Region) with
     Pre => Fits (R) and then Product_Bounded (R.Extent),
     Global => null;

   --  physical = origin + direction * (spacing .* index)
   --  Index components are absolute ITK indices, not offsets from Start.
   function To_Physical
     (Idx : Index; Spacing : Vector; Origin : Vector; Direction : Matrix)
      return Vector
   with Global => null, SPARK_Mode => Off;

   function Spacing_Valid (Spacing : Vector) return Boolean is
     (for all A in Axis => Spacing (A) /= 0.0)
   with Global => null;

   function To_Index
     (Point : Vector; Spacing : Vector; Origin : Vector; Direction : Matrix)
      return Index
   with Pre => Dimension in 2 .. 3 and then Spacing_Valid (Spacing),
        Global => null,
        SPARK_Mode => Off;

end Itklib.Core.Regions;
