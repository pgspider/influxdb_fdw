package main

/*
#include <stdlib.h>

typedef enum  InfluxDBType{
	INFLUXDB_INT64,
	INFLUXDB_DOUBLE,
	INFLUXDB_BOOLEAN,
	INFLUXDB_STRING
} InfluxDBType;

typedef union InfluxDBValue{
	long long int i;
	double d;
	int b;
	char *s;
} InfluxDBValue;

// Represents schema of one measurement(table)
typedef struct TableInfo {
	char *measurement;	// name
	char **tag; 		//array of tag name
	char **field;		//array of field name
	char **field_type;	//array of field type
	int tag_len;		//the number of tags
	int field_len;		//the number of fields
} TableInfo;

typedef struct InfluxDBRow {
	char **tuple;
} InfluxDBRow;

typedef struct InfluxDBResult {
	InfluxDBRow *rows;
	int ncol;
	int nrow;
} InfluxDBResult;
*/
import "C"

import (
	"encoding/json"
	"fmt"
	"strconv"
	"unsafe"

	"github.com/influxdata/influxdb1-client/models"
	"github.com/influxdata/influxdb1-client/v2"
)

// convenience function to query the database using one statement and one series
func queryDB(clnt client.Client, q client.Query) (res models.Row, err error) {

	if response, err := clnt.Query(q); err == nil {
		if response.Error() != nil {
			return res, response.Error()
		}

		if len(response.Results) == 0 || len(response.Results[0].Series) == 0 {
			//empty result is not error
			return models.Row{}, nil
		}
		res = response.Results[0].Series[0]
	} else {
		return res, err
	}
	return res, nil
}

// Allocate array of pointer
func allocCPointerArray(length int) unsafe.Pointer {
	return C.calloc(1, C.size_t((int(unsafe.Sizeof(uintptr(0))) * length)))
}

// Allocate array of C String
func allocCStringArray(length int) **C.char {
	len := int(unsafe.Sizeof(uintptr(0))) * length
	return (**C.char)(C.calloc(1, (C.size_t(len))))
}

//Convert array of C String to Go Slice
//Use a type conversion to a pointer to a very big array
//and then slice it to the length that you want
//https://github.com/golang/go/wiki/cgo
func cStringArrayToSlice(array **C.char, length int) [](*C.char) {
	return (*[1 << 30](*C.char))(unsafe.Pointer(array))[:length:length]
}

//export InfluxDBSchemaInfo
func InfluxDBSchemaInfo(addr *C.char, port C.int, user *C.char, pass *C.char,
	db *C.char) (retinfo *C.struct_TableInfo, length int, errret *C.char) {

	// Create a new HTTPClient
	c, err := client.NewHTTPClient(client.HTTPConfig{
		Addr:     C.GoString(addr) + ":" + strconv.Itoa(int(port)),
		Username: C.GoString(user),
		Password: C.GoString(pass),
	})
	if err != nil {
		return nil, 0, C.CString(err.Error())
	}

	dbname := C.GoString(db)
	query := client.Query{
		Command:  "SHOW MEASUREMENTS ON " + dbname,
		Database: dbname,
	}
	result, err := queryDB(c, query)
	if err != nil {
		return nil, 0, C.CString(err.Error())
	}

	info := (*C.struct_TableInfo)(allocCPointerArray(C.sizeof_struct_TableInfo * len(result.Values)))
	//See the explanation of cStringArrayToSlice
	tableInfo := (*[1 << 30]C.struct_TableInfo)(unsafe.Pointer(info))[:len(result.Values):len(result.Values)]

	defer func() {
		if errret != nil {
			InfluxDBFreeSchemaInfo(info, len(result.Values))
		}
	}()

	for i, v := range result.Values {
		measurement, b := v[0].(string)
		if !b {
			return nil, 0, C.CString("cannot convert to string" + fmt.Sprint(v[0]))
		}
		tableInfo[i].measurement = C.CString(measurement)

		tagresult, err := queryDB(c,
			client.Query{
				Command:  "SHOW TAG KEYS ON " + dbname + " FROM " + measurement,
				Database: dbname,
			})
		if err != nil {
			return nil, 0, C.CString(err.Error())
		}

		tableInfo[i].tag_len = C.int(len(tagresult.Values))
		tableInfo[i].tag = allocCStringArray(len(tagresult.Values))
		tags := cStringArrayToSlice(tableInfo[i].tag, len(tagresult.Values))
		for i, tag := range tagresult.Values {
			tags[i] = C.CString(tag[0].(string))
		}

		fieldresult, err := queryDB(c,
			client.Query{
				Command:  "SHOW FIELD KEYS ON " + dbname + " FROM " + measurement,
				Database: dbname,
			})
		if err != nil {
			return nil, 0, C.CString(err.Error())
		}

		// fill member of tableInfo

		fieldlen := len(fieldresult.Values)
		tableInfo[i].field_len = C.int(fieldlen)

		tableInfo[i].field = allocCStringArray(fieldlen)
		fields := cStringArrayToSlice(tableInfo[i].field, fieldlen)

		tableInfo[i].field_type = allocCStringArray(fieldlen)
		fieldtypes := cStringArrayToSlice(tableInfo[i].field_type, fieldlen)

		//SHOW FIELD KEYS returns one row for each column
		//first column of each row is column name, second column is column type
		for i, row := range fieldresult.Values {
			f, ok := row[0].(string)
			if !ok {
				return nil, 0, C.CString("cannot convert to string: " + fmt.Sprint(row[0]))
			}
			fields[i] = C.CString(f)

			t, ok := row[1].(string)
			if !ok {
				return nil, 0, C.CString("cannot convert to string: " + fmt.Sprint(row[1]))
			}
			fieldtypes[i] = C.CString(t)
		}
	}
	return info, len(result.Values), nil
}

//export InfluxDBFreeSchemaInfo
func InfluxDBFreeSchemaInfo(tableInfo *C.struct_TableInfo, length int) {
	if length <= 0 {
		return
	}
	info := (*[1 << 30]C.struct_TableInfo)(unsafe.Pointer(tableInfo))[:length:length]
	for _, v := range info {
		C.free(unsafe.Pointer(v.measurement))

		if v.tag == nil {
			return
		}
		tags := cStringArrayToSlice(v.tag, int(v.tag_len))
		for _, t := range tags {
			C.free(unsafe.Pointer(t))
		}

		if v.field_type == nil {
			return
		}
		fieldtypes := cStringArrayToSlice(v.field_type, int(v.field_len))
		for _, f := range fieldtypes {
			C.free(unsafe.Pointer(f))
		}

		if v.field == nil {
			return
		}
		fields := cStringArrayToSlice(v.field, int(v.field_len))
		for _, f := range fields {
			C.free(unsafe.Pointer(f))
		}
	}
}

//InfluxDBQuery returns result set
//export InfluxDBQuery
func InfluxDBQuery(cquery *C.char, addr *C.char, port C.int,
	user *C.char, pass *C.char, db *C.char,
	ctypes *C.InfluxDBType, cparam *C.InfluxDBValue, cparamNum C.int) (C.struct_InfluxDBResult, *C.char) {

	// Create a new HTTPClient
	cl, err := client.NewHTTPClient(client.HTTPConfig{
		Addr:     C.GoString(addr) + ":" + strconv.Itoa(int(port)),
		Username: C.GoString(user),
		Password: C.GoString(pass),
	})
	if err != nil {
		return C.InfluxDBResult{}, C.CString(err.Error())
	}

	query := client.Query{
		Command:  C.GoString(cquery),
		Database: C.GoString(db),
	}
	// Set query.Parameters to parameters
	paramNum := int(cparamNum)
	if cparamNum > 0 {
		param := (*[1 << 30]C.union_InfluxDBValue)(unsafe.Pointer(cparam))[:paramNum:paramNum]
		types := (*[1 << 30]C.enum_InfluxDBType)(unsafe.Pointer(ctypes))[:paramNum:paramNum]
		query.Parameters = make(map[string]interface{})

		// Query contains paramNum placeholder
		// Each placeholder is "$1", "$2",...,so set "1","2",... to map key
		for i := range param {
			switch types[i] {
			case C.INFLUXDB_INT64:
				//Cannot access union member in Go, so use cast
				query.Parameters[strconv.Itoa(i+1)] = *(*int64)(unsafe.Pointer(&param[i]))
				break
			case C.INFLUXDB_DOUBLE:
				query.Parameters[strconv.Itoa(i+1)] = *(*float64)(unsafe.Pointer(&(param[i])))
				break
			case C.INFLUXDB_BOOLEAN:
				b := *(*int32)(unsafe.Pointer(&(param[i])))
				val := false
				if b != 0 {
					val = true
				}
				query.Parameters[strconv.Itoa(i+1)] = val
				break
			case C.INFLUXDB_STRING:
				query.Parameters[strconv.Itoa(i+1)] = C.GoString(*(**C.char)(unsafe.Pointer(&(param[i]))))
				break
			default:
				return C.InfluxDBResult{}, C.CString("unexpected type: " + fmt.Sprint(types[i]))
			}
		}
	}

	// Query and get result
	rows, err := queryDB(cl, query)
	if err != nil {
		return C.InfluxDBResult{}, C.CString(err.Error())
	}

	//Convert result to C.struct_InfluxDBResult

	nrow := len(rows.Values)

	if nrow == 0 {
		return C.InfluxDBResult{}, nil
	}

	result := C.InfluxDBResult{
		ncol: C.int(len(rows.Values[0])),
		nrow: C.int(nrow),
		rows: (*C.struct_InfluxDBRow)(C.malloc(C.size_t(int(C.sizeof_struct_InfluxDBRow) * nrow))),
	}

	resultRows := (*[1 << 30]C.struct_InfluxDBRow)(unsafe.Pointer(result.rows))[:nrow:nrow]

	for i, row := range rows.Values {
		resultRows[i].tuple = allocCStringArray(len(row))
		tuple := cStringArrayToSlice(resultRows[i].tuple, len(row))
		//Convert each value to C string and set to tuple
		for j, c := range row {
			switch val := c.(type) {
			case nil:
				tuple[j] = nil
				break
			case json.Number:
				tuple[j] = C.CString(val.String())
				break
			case bool:
				if val {
					tuple[j] = C.CString("true")
				} else {
					tuple[j] = C.CString("false")
				}
				break
			case string:
				tuple[j] = C.CString(val)
				break

			default:
				return C.InfluxDBResult{}, C.CString("unexpected type: " + fmt.Sprint(val))
			}
		}
	}
	return result, nil
}

//export InfluxDBFreeResult
func InfluxDBFreeResult(result *C.struct_InfluxDBResult) {
	nrow := int(result.nrow)
	ncol := int(result.ncol)
	if nrow == 0 {
		return
	}
	resultRows := (*[1 << 30]C.struct_InfluxDBRow)(unsafe.Pointer(result.rows))[:nrow:nrow]
	for _, r := range resultRows {
		row := cStringArrayToSlice(r.tuple, ncol)
		for _, val := range row {
			if val != nil {
				C.free(unsafe.Pointer(val))
			}
		}
		C.free(unsafe.Pointer(r.tuple))
	}
	C.free(unsafe.Pointer(result.rows))
}

func main() {

}
