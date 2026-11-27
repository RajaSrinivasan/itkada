with Ada.Unchecked_Conversion;
with Interfaces.C.Strings;

package body Itklib.Thin with SPARK_Mode => Off is

   use type Interfaces.C.int;
   use type System.Address;

   type Object is null record with Convention => C;
   type Object_Ptr is access all Object with Convention => C, Storage_Size => 0;

   function Address_To_Pointer is new Ada.Unchecked_Conversion
     (System.Address, Object_Ptr);
   function Pointer_To_Address is new Ada.Unchecked_Conversion
     (Object_Ptr, System.Address);

   type Error_Record is record
      Code : Interfaces.C.int;
      What : Interfaces.C.char_array (1 .. 1024);
      Where : Interfaces.C.char_array (1 .. 256);
   end record
     with Convention => C;

   type C_U64_Array is
     array (Natural range <>) of aliased Interfaces.Unsigned_64
     with Convention => C;
   type C_I64_Array is
     array (Natural range <>) of aliased Interfaces.Integer_64
     with Convention => C;
   type C_F64_Array is
     array (Natural range <>) of aliased Interfaces.C.double
     with Convention => C;

   function To_Pointer (Handle : System.Address) return Object_Ptr is
     (if Handle = System.Null_Address then null else Address_To_Pointer (Handle));

   function To_Handle (Pointer : Object_Ptr) return System.Address is
     (if Pointer = null then System.Null_Address
      else Pointer_To_Address (Pointer));

   function Pixel_Id (Kind : Itklib.Pixel_Kind) return Interfaces.C.int is
   begin
      case Kind is
         when Itklib.UInt8 =>
            return 1;
         when Itklib.Int8 =>
            return 2;
         when Itklib.UInt16 =>
            return 3;
         when Itklib.Int16 =>
            return 4;
         when Itklib.UInt32 =>
            return 5;
         when Itklib.Int32 =>
            return 6;
         when Itklib.UInt64 =>
            return 7;
         when Itklib.Int64 =>
            return 8;
         when Itklib.Float32 =>
            return 9;
         when Itklib.Float64 =>
            return 10;
      end case;
   end Pixel_Id;

   function Message (Error : Error_Record) return String is
      What : constant String :=
        Interfaces.C.To_Ada (Error.What, Trim_Nul => True);
      Where : constant String :=
        Interfaces.C.To_Ada (Error.Where, Trim_Nul => True);
   begin
      if Where'Length = 0 then
         return What;
      else
         return What & " (" & Where & ")";
      end if;
   end Message;

   procedure Check (Code : Interfaces.C.int; Error : Error_Record) is
   begin
      case Code is
         when 0 =>
            null;
         when 2 =>
            raise Itklib.Unsupported_Instantiation with Message (Error);
         when 3 =>
            raise Storage_Error with Message (Error);
         when others =>
            raise Itklib.Itk_Error with Message (Error);
      end case;
   end Check;

   procedure Require (Handle : System.Address) is
   begin
      if Handle = System.Null_Address then
         raise Itklib.Itk_Error with "null ITK handle";
      end if;
   end Require;

   function As_Natural (Value : Interfaces.C.int) return Natural is
   begin
      if Value <= 0 then
         return 0;
      end if;
      return Natural (Value);
   end As_Natural;

   function itklib_itk_version return Interfaces.C.Strings.chars_ptr with
     Import, Convention => C, External_Name => "itklib_itk_version";

   function itklib_supported
     (Pixel : Interfaces.C.int; Dimension : Interfaces.C.unsigned)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_supported";

   procedure itklib_register (Object : Object_Ptr) with
     Import, Convention => C, External_Name => "itklib_register";

   procedure itklib_unregister (Object : Object_Ptr) with
     Import, Convention => C, External_Name => "itklib_unregister";

   function itklib_reference_count (Object : Object_Ptr) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_reference_count";

   function itklib_debug_live_objects return Interfaces.C.int with
     Import, Convention => C, External_Name => "itklib_debug_live_objects";

   function itklib_debug_live_wrappers return Interfaces.C.int with
     Import, Convention => C, External_Name => "itklib_debug_live_wrappers";

   function itklib_image_new
     (Pixel : Interfaces.C.int; Dimension : Interfaces.C.unsigned;
      Size : access constant Interfaces.Unsigned_64;
      Out_Object : access Object_Ptr; Error : access Error_Record)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_image_new";

   function itklib_image_buffer
     (Image : Object_Ptr; Data : access System.Address;
      Count : access Interfaces.Unsigned_64; Error : access Error_Record)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_image_buffer";

   function itklib_image_get_geometry
     (Image : Object_Ptr; Index : access Interfaces.Integer_64;
      Size : access Interfaces.Unsigned_64; Spacing : access Interfaces.C.double;
      Origin : access Interfaces.C.double; Direction : access Interfaces.C.double;
      Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_image_get_geometry";

   function itklib_image_set_spacing
     (Image : Object_Ptr; Spacing : access constant Interfaces.C.double;
      Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_image_set_spacing";

   function itklib_image_set_origin
     (Image : Object_Ptr; Origin : access constant Interfaces.C.double;
      Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_image_set_origin";

   function itklib_image_set_direction
     (Image : Object_Ptr; Direction : access constant Interfaces.C.double;
      Error : access Error_Record) return Interfaces.C.int
     with
       Import, Convention => C, External_Name => "itklib_image_set_direction";

   function itklib_reader_new
     (Pixel : Interfaces.C.int; Dimension : Interfaces.C.unsigned;
      Out_Object : access Object_Ptr; Error : access Error_Record)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_reader_new";

   function itklib_reader_set_file
     (Reader : Object_Ptr; Path : Interfaces.C.Strings.chars_ptr;
      Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_reader_set_file";

   function itklib_writer_new
     (Pixel : Interfaces.C.int; Dimension : Interfaces.C.unsigned;
      Out_Object : access Object_Ptr; Error : access Error_Record)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_writer_new";

   function itklib_writer_set_file
     (Writer : Object_Ptr; Path : Interfaces.C.Strings.chars_ptr;
      Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_writer_set_file";

   function itklib_discrete_gaussian_new
     (Input_Pixel : Interfaces.C.int; Output_Pixel : Interfaces.C.int;
      Dimension : Interfaces.C.unsigned; Out_Object : access Object_Ptr;
      Error : access Error_Record) return Interfaces.C.int
     with
       Import, Convention => C, External_Name => "itklib_discrete_gaussian_new";

   function itklib_discrete_gaussian_set_variance
     (Filter : Object_Ptr; Variance : access constant Interfaces.C.double;
      Error : access Error_Record) return Interfaces.C.int
     with
       Import,
       Convention => C,
       External_Name => "itklib_discrete_gaussian_set_variance";

   function itklib_discrete_gaussian_set_use_image_spacing
     (Filter : Object_Ptr; Enabled : Interfaces.C.int; Error : access Error_Record)
      return Interfaces.C.int
     with
       Import,
       Convention => C,
       External_Name => "itklib_discrete_gaussian_set_use_image_spacing";

   function itklib_set_input
     (Filter : Object_Ptr; Index : Interfaces.C.unsigned; Image : Object_Ptr;
      Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_set_input";

   function itklib_update
     (Process : Object_Ptr; Error : access Error_Record) return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_update";

   function itklib_get_output
     (Process : Object_Ptr; Index : Interfaces.C.unsigned;
      Image : access Object_Ptr; Error : access Error_Record)
      return Interfaces.C.int
     with Import, Convention => C, External_Name => "itklib_get_output";

   function ITK_Version return String is
   begin
      return Interfaces.C.Strings.Value (itklib_itk_version);
   end ITK_Version;

   function Is_Supported
     (Kind : Itklib.Pixel_Kind; Dimension : Positive) return Boolean is
   begin
      return
        itklib_supported (Pixel_Id (Kind), Interfaces.C.unsigned (Dimension))
        /= 0;
   end Is_Supported;

   function Debug_Live_Objects return Natural is
   begin
      return As_Natural (itklib_debug_live_objects);
   end Debug_Live_Objects;

   function Debug_Live_Wrappers return Natural is
   begin
      return As_Natural (itklib_debug_live_wrappers);
   end Debug_Live_Wrappers;

   procedure Register (Handle : System.Address) is
   begin
      if Handle /= System.Null_Address then
         itklib_register (To_Pointer (Handle));
      end if;
   end Register;

   procedure Unregister (Handle : System.Address) is
   begin
      if Handle /= System.Null_Address then
         itklib_unregister (To_Pointer (Handle));
      end if;
   end Unregister;

   function Reference_Count (Handle : System.Address) return Natural is
   begin
      if Handle = System.Null_Address then
         return 0;
      end if;
      return As_Natural (itklib_reference_count (To_Pointer (Handle)));
   end Reference_Count;

   function Image_New
     (Kind : Itklib.Pixel_Kind; Extent : Extent_Array) return System.Address
   is
      Size : C_U64_Array (0 .. Extent'Length - 1);
      Out_Object : aliased Object_Ptr := null;
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      for K in Extent'Range loop
         Size (K - Extent'First) := Extent (K);
      end loop;
      Code :=
        itklib_image_new
          (Pixel_Id (Kind), Interfaces.C.unsigned (Extent'Length),
           Size (0)'Unchecked_Access, Out_Object'Unchecked_Access,
           Error'Unchecked_Access);
      Check (Code, Error);
      return To_Handle (Out_Object);
   end Image_New;

   procedure Image_Buffer
     (Handle : System.Address; Data : out System.Address;
      Count : out Interfaces.Unsigned_64)
   is
      Data_Slot : aliased System.Address := System.Null_Address;
      Count_Slot : aliased Interfaces.Unsigned_64 := 0;
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      Code :=
        itklib_image_buffer
          (To_Pointer (Handle), Data_Slot'Unchecked_Access,
           Count_Slot'Unchecked_Access, Error'Unchecked_Access);
      Check (Code, Error);
      Data := Data_Slot;
      Count := Count_Slot;
   end Image_Buffer;

   procedure Image_Get_Geometry
     (Handle : System.Address; Index : out Index_Array; Size : out Extent_Array;
      Spacing : out Double_Array; Origin : out Double_Array;
      Direction : out Double_Array)
   is
      N : constant Natural := Index'Length;
      C_Index : C_I64_Array (0 .. N - 1);
      C_Size : C_U64_Array (0 .. N - 1);
      C_Spacing : C_F64_Array (0 .. N - 1);
      C_Origin : C_F64_Array (0 .. N - 1);
      C_Direction : C_F64_Array (0 .. N * N - 1);
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      if Size'Length /= N or else Spacing'Length /= N or else Origin'Length /= N
        or else Direction'Length /= N * N
      then
         raise Itklib.Itk_Error with "geometry array lengths do not match";
      end if;
      Code :=
        itklib_image_get_geometry
          (To_Pointer (Handle), C_Index (0)'Unchecked_Access,
           C_Size (0)'Unchecked_Access, C_Spacing (0)'Unchecked_Access,
           C_Origin (0)'Unchecked_Access, C_Direction (0)'Unchecked_Access,
           Error'Unchecked_Access);
      Check (Code, Error);
      for K in 0 .. N - 1 loop
         Index (Index'First + K) := C_Index (K);
         Size (Size'First + K) := C_Size (K);
         Spacing (Spacing'First + K) := C_Spacing (K);
         Origin (Origin'First + K) := C_Origin (K);
      end loop;
      for K in C_Direction'Range loop
         Direction (Direction'First + K) := C_Direction (K);
      end loop;
   end Image_Get_Geometry;

   procedure Image_Set_Spacing
     (Handle : System.Address; Spacing : Double_Array)
   is
      Raw : C_F64_Array (0 .. Spacing'Length - 1);
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      for K in Spacing'Range loop
         Raw (K - Spacing'First) := Spacing (K);
      end loop;
      Code :=
        itklib_image_set_spacing
          (To_Pointer (Handle), Raw (0)'Unchecked_Access,
           Error'Unchecked_Access);
      Check (Code, Error);
   end Image_Set_Spacing;

   procedure Image_Set_Origin (Handle : System.Address; Origin : Double_Array) is
      Raw : C_F64_Array (0 .. Origin'Length - 1);
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      for K in Origin'Range loop
         Raw (K - Origin'First) := Origin (K);
      end loop;
      Code :=
        itklib_image_set_origin
          (To_Pointer (Handle), Raw (0)'Unchecked_Access, Error'Unchecked_Access);
      Check (Code, Error);
   end Image_Set_Origin;

   procedure Image_Set_Direction
     (Handle : System.Address; Direction : Double_Array)
   is
      Raw : C_F64_Array (0 .. Direction'Length - 1);
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      for K in Direction'Range loop
         Raw (K - Direction'First) := Direction (K);
      end loop;
      Code :=
        itklib_image_set_direction
          (To_Pointer (Handle), Raw (0)'Unchecked_Access,
           Error'Unchecked_Access);
      Check (Code, Error);
   end Image_Set_Direction;

   function Factory_New
     (Kind : Itklib.Pixel_Kind; Dimension : Positive; Which : Positive)
      return System.Address
   is
      Out_Object : aliased Object_Ptr := null;
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
      Pixel : constant Interfaces.C.int := Pixel_Id (Kind);
      Dim : constant Interfaces.C.unsigned := Interfaces.C.unsigned (Dimension);
   begin
      case Which is
         when 1 =>
            Code :=
              itklib_reader_new
                (Pixel, Dim, Out_Object'Unchecked_Access, Error'Unchecked_Access);
         when 2 =>
            Code :=
              itklib_writer_new
                (Pixel, Dim, Out_Object'Unchecked_Access, Error'Unchecked_Access);
         when others =>
            Code :=
              itklib_discrete_gaussian_new
                (Pixel, Pixel, Dim, Out_Object'Unchecked_Access,
                 Error'Unchecked_Access);
      end case;
      Check (Code, Error);
      return To_Handle (Out_Object);
   end Factory_New;

   function Reader_New
     (Kind : Itklib.Pixel_Kind; Dimension : Positive) return System.Address is
   begin
      return Factory_New (Kind, Dimension, 1);
   end Reader_New;

   function Writer_New
     (Kind : Itklib.Pixel_Kind; Dimension : Positive) return System.Address is
   begin
      return Factory_New (Kind, Dimension, 2);
   end Writer_New;

   function Gaussian_New
     (Kind : Itklib.Pixel_Kind; Dimension : Positive) return System.Address is
   begin
      return Factory_New (Kind, Dimension, 3);
   end Gaussian_New;

   procedure Set_File
     (Handle : System.Address; Path : String; Writer : Boolean)
   is
      use Interfaces.C.Strings;
      C_Path : chars_ptr := New_String (Path);
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      if Writer then
         Code :=
           itklib_writer_set_file
             (To_Pointer (Handle), C_Path, Error'Unchecked_Access);
      else
         Code :=
           itklib_reader_set_file
             (To_Pointer (Handle), C_Path, Error'Unchecked_Access);
      end if;
      Free (C_Path);
      Check (Code, Error);
   end Set_File;

   procedure Reader_Set_File (Handle : System.Address; Path : String) is
   begin
      Set_File (Handle, Path, False);
   end Reader_Set_File;

   procedure Writer_Set_File (Handle : System.Address; Path : String) is
   begin
      Set_File (Handle, Path, True);
   end Writer_Set_File;

   procedure Gaussian_Set_Variance
     (Handle : System.Address; Variance : Double_Array)
   is
      Raw : C_F64_Array (0 .. Variance'Length - 1);
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Handle);
      for K in Variance'Range loop
         Raw (K - Variance'First) := Variance (K);
      end loop;
      Code :=
        itklib_discrete_gaussian_set_variance
          (To_Pointer (Handle), Raw (0)'Unchecked_Access, Error'Unchecked_Access);
      Check (Code, Error);
   end Gaussian_Set_Variance;

   procedure Gaussian_Set_Use_Image_Spacing
     (Handle : System.Address; Enabled : Boolean)
   is
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
      Flag : Interfaces.C.int := 0;
   begin
      Require (Handle);
      if Enabled then
         Flag := 1;
      end if;
      Code :=
        itklib_discrete_gaussian_set_use_image_spacing
          (To_Pointer (Handle), Flag, Error'Unchecked_Access);
      Check (Code, Error);
   end Gaussian_Set_Use_Image_Spacing;

   procedure Set_Input
     (Filter : System.Address; Image : System.Address; Index : Natural := 0)
   is
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Filter);
      Require (Image);
      Code :=
        itklib_set_input
          (To_Pointer (Filter), Interfaces.C.unsigned (Index), To_Pointer (Image),
           Error'Unchecked_Access);
      Check (Code, Error);
   end Set_Input;

   procedure Update (Process : System.Address) is
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Process);
      Code := itklib_update (To_Pointer (Process), Error'Unchecked_Access);
      Check (Code, Error);
   end Update;

   function Get_Output
     (Process : System.Address; Index : Natural := 0) return System.Address
   is
      Out_Object : aliased Object_Ptr := null;
      Error : aliased Error_Record;
      Code : Interfaces.C.int;
   begin
      Require (Process);
      Code :=
        itklib_get_output
          (To_Pointer (Process), Interfaces.C.unsigned (Index),
           Out_Object'Unchecked_Access, Error'Unchecked_Access);
      Check (Code, Error);
      return To_Handle (Out_Object);
   end Get_Output;

end Itklib.Thin;
