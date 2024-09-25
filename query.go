package main

// #cgo CFLAGS: -fPIC
/*
#include <stdlib.h>

typedef enum InfluxDBType{
	INFLUXDB_INT64,
	INFLUXDB_DOUBLE,
	INFLUXDB_BOOLEAN,
	INFLUXDB_STRING,
	INFLUXDB_TIME,
	INFLUXDB_NULL
} InfluxDBType;

typedef union InfluxDBValue{
	long long int i;
	double d;
	int b;
	char *s;
} InfluxDBValue;

// Represents schema of one measurement(table)
typedef struct TableInfo {
	char *measurement;	//name
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
	char **columns;
	char **tagkeys;
	int ntag;
} InfluxDBResult;

typedef enum InfluxDBColumnType{
	INFLUXDB_UNKNOWN_KEY,
	INFLUXDB_TIME_KEY,
	INFLUXDB_TAG_KEY,
	INFLUXDB_FIELD_KEY
} InfluxDBColumnType;

typedef struct InfluxDBColumnInfo {
	char *column_name;				//name of column
	InfluxDBColumnType column_type;	//type of column
} InfluxDBColumnInfo;
*/
import "C"

import (
	"encoding/json"
	"fmt"
	"math"
	"strconv"
	"time"
	"unsafe"

	"github.com/influxdata/influxdb1-client/models"
	client "github.com/influxdata/influxdb1-client/v2"
)

const timestamptzFormat = "2006-01-02 15:04:05.999999-07"

var timeFormat = []string{
	"2006-01-02T15:04:05.999999999Z07:00",
	"2006-01-02T15:04:05.999999999Z",
	"2006-01-02 15:04:05.999999999-07",
	"2006-01-02 15:04:05.999999999",
	"Mon Jan 02 15:04:05.999999999 2006 MST",
	"Mon Jan 02 15:04:05.999999999 2006",
	"15:04:05.999999999-07",
	"15:04:05.999999999",
}

//convenience function to query the database using one statement and one series
func queryDB(clnt client.Client, q client.Query) (res models.Row, err error) {
	rows, err := queryDBRows(clnt, q)
	if err != nil {
		return res, err
	}
	if len(rows) == 0 {
		return res, nil
	}
	return rows[0], nil
}

func queryDBRows(clnt client.Client, q client.Query) (res []models.Row, err error) {
	response, err := clnt.Query(q)
	if err != nil {
		return res, err
	}
	if response.Error() != nil {
		return res, response.Error()
	}

	if len(response.Results) == 0 {
		//empty result is not error
		return res, nil
	}
	res = response.Results[0].Series
	return res, nil
}

//Allocate array of pointer
func allocCPointerArray(length int) unsafe.Pointer {
	return C.calloc(1, C.size_t((int(unsafe.Sizeof(uintptr(0))) * length)))
}

//Allocate array of C String
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

//Parse time from timeString
func parseTime(timeString string) (time.Time, error) {
	for _, form := range timeFormat {
		times, err := time.Parse(form, timeString)
		if err == nil {
			//Parse time value successful
			return times, nil
		}
	}
	//Parse time value unsuccessful
	return time.Now(), fmt.Errorf("parsing time %q error", timeString)
}

//InfluxDBSchemaInfo returns information of table if success
//export InfluxDBSchemaInfo
func InfluxDBSchemaInfo(addr *C.char, port C.int, user *C.char, pass *C.char,
	db *C.char) (retinfo *C.struct_TableInfo, length int, errret *C.char) {

	//Create a new HTTPClient
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

		//fill member of tableInfo

		fieldLen := len(fieldresult.Values)
		tableInfo[i].field_len = C.int(fieldLen)

		tableInfo[i].field = allocCStringArray(fieldLen)
		fields := cStringArrayToSlice(tableInfo[i].field, fieldLen)

		tableInfo[i].field_type = allocCStringArray(fieldLen)
		fieldtypes := cStringArrayToSlice(tableInfo[i].field_type, fieldLen)

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

//InfluxDBFreeSchemaInfo returns nothing
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

func bindParameter(ctypes *C.InfluxDBType, cvalues *C.InfluxDBValue, cparamNum C.int, query *client.Query) error {
	//Set query.Parameters to parameters
	paramNum := int(cparamNum)

	if cparamNum > 0 {
		values := (*[1 << 30]C.union_InfluxDBValue)(unsafe.Pointer(cvalues))[:paramNum:paramNum]
		types := (*[1 << 30]C.enum_InfluxDBType)(unsafe.Pointer(ctypes))[:paramNum:paramNum]
		query.Parameters = make(map[string]interface{})

		//Query contains paramNum placeholder
		//Each placeholder is "$1", "$2",...,so set "1","2",... to map key
		for i := range values {
			switch types[i] {
			case C.INFLUXDB_TIME, C.INFLUXDB_INT64:
				//Cannot access union member in Go, so use cast
				query.Parameters[strconv.Itoa(i+1)] = *(*int64)(unsafe.Pointer(&values[i]))
				break
			case C.INFLUXDB_DOUBLE:
				query.Parameters[strconv.Itoa(i+1)] = *(*float64)(unsafe.Pointer(&(values[i])))
				break
			case C.INFLUXDB_BOOLEAN:
				b := *(*int32)(unsafe.Pointer(&(values[i])))
				val := false
				if b != 0 {
					val = true
				}
				query.Parameters[strconv.Itoa(i+1)] = val
				break
			case C.INFLUXDB_STRING:
				query.Parameters[strconv.Itoa(i+1)] = C.GoString(*(**C.char)(unsafe.Pointer(&(values[i]))))
				break
			case C.INFLUXDB_NULL:
				query.Parameters[strconv.Itoa(i+1)] = ""
				break
			default:
				return fmt.Errorf("unexpected type: %v", types[i])
			}
		}
	}
	return nil
}

//InfluxDBQuery returns result set
//export InfluxDBQuery
func InfluxDBQuery(cquery *C.char, addr *C.char, port C.int,
	user *C.char, pass *C.char, db *C.char,
	ctypes *C.InfluxDBType, cvalues *C.InfluxDBValue, cparamNum C.int) (C.struct_InfluxDBResult, *C.char) {

	//Create a new HTTPClient
	cl, err := client.NewHTTPClient(client.HTTPConfig{
		Addr:     C.GoString(addr) + ":" + strconv.Itoa(int(port)),
		Username: C.GoString(user),
		Password: C.GoString(pass),
	})
	if err != nil {
		return C.InfluxDBResult{}, C.CString(err.Error())
	}
	defer cl.Close()

	query := client.Query{
		Command:  C.GoString(cquery),
		Database: C.GoString(db),
	}
	err = bindParameter(ctypes, cvalues, cparamNum, &query)
	if err != nil {
		return C.InfluxDBResult{}, C.CString(err.Error())
	}

	//Query and get result
	rows, err := queryDBRows(cl, query)
	if err != nil {
		return C.InfluxDBResult{}, C.CString(err.Error())
	}

	//Convert result to C.struct_InfluxDBResult
	nrow := 0
	for _, row := range rows {
		nrow += len(row.Values)
	}

	//Returns empty result, not error
	if nrow == 0 {
		return C.InfluxDBResult{}, nil
	}

	fieldLen := len(rows[0].Columns)
	tagLen := len(rows[0].Tags)

	result := C.InfluxDBResult{
		ncol:    C.int(fieldLen + tagLen),
		nrow:    C.int(nrow),
		columns: allocCStringArray(fieldLen),
		rows:    (*C.struct_InfluxDBRow)(C.malloc(C.size_t(int(C.sizeof_struct_InfluxDBRow) * nrow))),
		ntag:    C.int(tagLen),
		tagkeys: allocCStringArray(tagLen),
	}

	ctagkeys := cStringArrayToSlice(result.tagkeys, tagLen)

	tagkeys := make([]string, tagLen)
	i := 0
	for key := range rows[0].Tags {
		tagkeys[i] = key
		ctagkeys[i] = C.CString(key)
		i++
	}

	// Get the list of column name
	i = 0
	ntuple := cStringArrayToSlice(result.columns, fieldLen)
	for _, row := range rows[0].Columns {
		ntuple[i] = C.CString(row)
		i++
	}

	resultRows := (*[1 << 30]C.struct_InfluxDBRow)(unsafe.Pointer(result.rows))[:nrow:nrow]
	rowidx := 0
	for _, row := range rows {
		for _, ival := range row.Values {
			resultRows[rowidx].tuple = allocCStringArray(len(ival) + tagLen)
			tuple := cStringArrayToSlice(resultRows[rowidx].tuple, len(ival)+tagLen)
			rowidx++

			//Convert each value to C string and set to tuple
			for j, c := range ival {
				switch val := c.(type) {
				case nil:
					tuple[j] = nil
				case json.Number:
					tuple[j] = C.CString(val.String())
				case bool:
					if val {
						tuple[j] = C.CString("true")
					} else {
						tuple[j] = C.CString("false")
					}
				case string:
					tuple[j] = C.CString(val)
				default:
					return C.InfluxDBResult{}, C.CString("unexpected type: " + fmt.Sprint(val))
				}
			}
			for k, v := range tagkeys {
				tuple[fieldLen+k] = C.CString(row.Tags[v])
			}
		}
	}

	//Clear tagkeys
	tagkeys = nil

	return result, nil
}

//InfluxDBFreeResult returns nothing
//export InfluxDBFreeResult
func InfluxDBFreeResult(result *C.struct_InfluxDBResult) {
	if result == nil {
		return
	}

	nrow := int(result.nrow)
	ncol := int(result.ncol)
	ntag := int(result.ntag)

	if nrow == 0 {
		return
	}

	//Free column
	resultCols := cStringArrayToSlice(result.columns, ncol - ntag)
	for _, col := range resultCols {
		C.free(unsafe.Pointer(col))
	}
	C.free(unsafe.Pointer(result.columns))

	//Free tuple
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

	//Free tagkey
	resultTagKeys := cStringArrayToSlice(result.tagkeys, ntag)
	for _, tagkey := range resultTagKeys {
		C.free(unsafe.Pointer(tagkey))
	}
	C.free(unsafe.Pointer(result.tagkeys))
}

func makeBatchPoint(db *C.char, tablename *C.char, ccolumns *C.struct_InfluxDBColumnInfo, ctypes *C.InfluxDBType,
	cvalues *C.InfluxDBValue, cparamNum C.int, cnumSlots C.int) (client.BatchPoints, error) {
	//Create a new point batch
	bp, _ := client.NewBatchPoints(client.BatchPointsConfig{
		Database: C.GoString(db),
	})

	//Wait a microsecond to ensure different timestamps with previous batch
	time.Sleep(1 * time.Microsecond)

	//Initialize tags, fields and time value
	paramNum := int(cparamNum) * int(cnumSlots)
	endOfPoint := float64(cparamNum - 1)
	fields := make(map[string]interface{})
	tags := make(map[string]string)
	timecol, _ := time.Parse(timestamptzFormat, time.Now().Format(timestamptzFormat))
	prev_time := timecol

	if cparamNum > 0 {
		columnInfo := (*[1 << 30]C.struct_InfluxDBColumnInfo)(unsafe.Pointer(ccolumns))[:paramNum:paramNum]
		values := (*[1 << 30]C.union_InfluxDBValue)(unsafe.Pointer(cvalues))[:paramNum:paramNum]
		types := (*[1 << 30]C.enum_InfluxDBType)(unsafe.Pointer(ctypes))[:paramNum:paramNum]

		//Type of tags key and time column always is String, so other types always is fields key
		for i := range values {
			switch types[i] {
			case C.INFLUXDB_INT64:
				fields[C.GoString(*(**C.char)(unsafe.Pointer(&(columnInfo[i].column_name))))] = *(*int64)(unsafe.Pointer(&values[i]))
				break
			case C.INFLUXDB_DOUBLE:
				fields[C.GoString(*(**C.char)(unsafe.Pointer(&(columnInfo[i].column_name))))] = *(*float64)(unsafe.Pointer(&(values[i])))
				break
			case C.INFLUXDB_BOOLEAN:
				b := *(*int32)(unsafe.Pointer(&(values[i])))
				val := false
				if b != 0 {
					val = true
				}
				fields[C.GoString(*(**C.char)(unsafe.Pointer(&(columnInfo[i].column_name))))] = val
				break
			case C.INFLUXDB_STRING:
				switch columnInfo[i].column_type {
				case C.INFLUXDB_TIME_KEY:
					//We need to parse time value from String to Time type
					timeString := C.GoString(*(**C.char)(unsafe.Pointer(&(values[i]))))
					times, err := parseTime(timeString)
					if err != nil {
						//Parse time value unsuccessful
						return bp, err
					}
					timecol = times
					break
				case C.INFLUXDB_TAG_KEY:
					tags[C.GoString(*(**C.char)(unsafe.Pointer(&(columnInfo[i].column_name))))] = C.GoString(*(**C.char)(unsafe.Pointer(&(values[i]))))
					break
				case C.INFLUXDB_FIELD_KEY:
					fields[C.GoString(*(**C.char)(unsafe.Pointer(&(columnInfo[i].column_name))))] = C.GoString(*(**C.char)(unsafe.Pointer(&(values[i]))))
					break
				}
				break
			case C.INFLUXDB_TIME:
				//Bind timestamp as epoch time
				timecol = time.Unix(0, *(*int64)(unsafe.Pointer(&values[i])))
				break
			case C.INFLUXDB_NULL:
				//We do not need append null value when execute INSERT
				break
			default:
				return bp, fmt.Errorf("unexpected type: %v", types[i])
			}

			//Make Point and add Point into BatchPoint
			if math.Mod(float64(i), float64(cparamNum)) == endOfPoint {
				//Create a point and add to batch
				pt, err := client.NewPoint(C.GoString(tablename), tags, fields, timecol)
				if err != nil {
					return bp, err
				}

				bp.AddPoint(pt)

				//Reset value of record
				fields = make(map[string]interface{})
				tags = make(map[string]string)
				//Busy wait to different timestamp
				for {
					timecol, _ = time.Parse(timestamptzFormat, time.Now().Format(timestamptzFormat))
					if (timecol.After(prev_time)) {
						break
					}
				}
				prev_time = timecol

			}
		}
	}

	return bp, nil
}

//InfluxDBInsert returns nil if success
//export InfluxDBInsert
func InfluxDBInsert(addr *C.char, port C.int, user *C.char, pass *C.char, db *C.char,
	tablename *C.char, ccolumns *C.struct_InfluxDBColumnInfo, ctypes *C.InfluxDBType,
	cvalues *C.InfluxDBValue, cparamNum C.int, cnumSlots C.int) *C.char {

	//Create a new HTTPClient
	cl, err := client.NewHTTPClient(client.HTTPConfig{
		Addr:     C.GoString(addr) + ":" + strconv.Itoa(int(port)),
		Username: C.GoString(user),
		Password: C.GoString(pass),
	})
	if err != nil {
		return C.CString(err.Error())
	}
	defer cl.Close()

	//Make the batch point
	bp, err := makeBatchPoint(db, tablename, ccolumns, ctypes, cvalues, cparamNum, cnumSlots)
	if err != nil {
		return C.CString(err.Error())
	}

	//Write the batch
	err = cl.Write(bp)
	if err != nil {
		return C.CString(err.Error())
	}

	return nil
}

//InfluxDBExecDDLCommand drop a measurement
// Return nil if success, otherwise return error message
//export InfluxDBExecDDLCommand
func InfluxDBExecDDLCommand(addr *C.char, port C.int, user *C.char, pass *C.char,
	db *C.char, cquery *C.char) (errret *C.char) {

	//Create a new HTTPClient
	c, err := client.NewHTTPClient(client.HTTPConfig{
		Addr:     C.GoString(addr) + ":" + strconv.Itoa(int(port)),
		Username: C.GoString(user),
		Password: C.GoString(pass),
	})
	if err != nil {
		return C.CString(err.Error())
	}

	query := client.Query{
		Command:  C.GoString(cquery),
		Database: C.GoString(db),
	}
	_, err = queryDB(c, query)
	if err != nil {
		return C.CString(err.Error())
	}

	return nil
}

func main() {

}
